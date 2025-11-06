#!/usr/bin/env python3
"""
Proxmox Autoscaler for k3s Worker Nodes
Monitors cluster load and scales worker nodes based on CPU, memory, and traffic metrics
"""

import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional

import requests
from proxmoxer import ProxmoxAPI
from kubernetes import client, config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ProxmoxAutoscaler:
    """Autoscaler for Proxmox VMs based on Kubernetes metrics"""

    def __init__(
        self,
        proxmox_host: str,
        proxmox_user: str,
        proxmox_token_name: str,
        proxmox_token_value: str,
        verify_ssl: bool = False
    ):
        """Initialize Proxmox connection"""
        self.proxmox = ProxmoxAPI(
            proxmox_host,
            user=proxmox_user,
            token_name=proxmox_token_name,
            token_value=proxmox_token_value,
            verify_ssl=verify_ssl
        )
        
        # Load Kubernetes config
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        
        self.k8s_core = client.CoreV1Api()
        self.k8s_metrics = client.CustomObjectsApi()
        
        # Scaling state
        self.last_scale_time = None
        self.cooldown_period = timedelta(seconds=300)  # 5 minutes
        
    def get_cluster_metrics(self) -> Dict:
        """Get aggregate cluster metrics from Kubernetes"""
        try:
            # Get node metrics
            nodes = self.k8s_core.list_node()
            node_metrics = self.k8s_metrics.list_cluster_custom_object(
                group="metrics.k8s.io",
                version="v1beta1",
                plural="nodes"
            )
            
            total_cpu_capacity = 0
            total_cpu_usage = 0
            total_memory_capacity = 0
            total_memory_usage = 0
            worker_nodes = 0
            
            for node in nodes.items:
                # Skip control plane nodes
                if 'node-role.kubernetes.io/control-plane' in node.metadata.labels:
                    continue
                
                worker_nodes += 1
                
                # CPU capacity (in millicores)
                cpu_capacity = self._parse_cpu(node.status.allocatable['cpu'])
                total_cpu_capacity += cpu_capacity
                
                # Memory capacity (in bytes)
                memory_capacity = self._parse_memory(node.status.allocatable['memory'])
                total_memory_capacity += memory_capacity
                
                # Get usage from metrics
                for metric in node_metrics['items']:
                    if metric['metadata']['name'] == node.metadata.name:
                        cpu_usage = self._parse_cpu(metric['usage']['cpu'])
                        memory_usage = self._parse_memory(metric['usage']['memory'])
                        total_cpu_usage += cpu_usage
                        total_memory_usage += memory_usage
                        break
            
            cpu_percent = (total_cpu_usage / total_cpu_capacity * 100) if total_cpu_capacity > 0 else 0
            memory_percent = (total_memory_usage / total_memory_capacity * 100) if total_memory_capacity > 0 else 0
            
            # Get pod metrics for traffic estimation
            pods = self.k8s_core.list_pod_for_all_namespaces()
            total_pods = len([p for p in pods.items if p.status.phase == 'Running'])
            
            metrics = {
                'timestamp': datetime.now().isoformat(),
                'worker_nodes': worker_nodes,
                'cpu_percent': round(cpu_percent, 2),
                'memory_percent': round(memory_percent, 2),
                'total_pods': total_pods,
                'cpu_capacity_cores': total_cpu_capacity / 1000,
                'memory_capacity_gb': total_memory_capacity / (1024**3)
            }
            
            logger.info(f"Cluster metrics: {json.dumps(metrics, indent=2)}")
            return metrics
            
        except Exception as e:
            logger.error(f"Failed to get cluster metrics: {e}")
            return {}
    
    def get_asg_vms(self) -> List[Dict]:
        """Get all autoscaling group VMs"""
        asg_vms = []
        
        for node in self.proxmox.nodes.get():
            node_name = node['node']
            
            for vm in self.proxmox.nodes(node_name).qemu.get():
                # Check if VM has autoscale tag
                vm_config = self.proxmox.nodes(node_name).qemu(vm['vmid']).config.get()
                tags = vm_config.get('tags', '')
                
                if 'asg-dynamic' in tags or 'autoscale' in tags:
                    asg_vms.append({
                        'vmid': vm['vmid'],
                        'name': vm['name'],
                        'node': node_name,
                        'status': vm['status'],
                        'tags': tags
                    })
        
        return asg_vms
    
    def scale_up(self, count: int = 1) -> bool:
        """Scale up by starting stopped ASG VMs"""
        if not self._can_scale():
            logger.info("Cooldown period active, skipping scale up")
            return False
        
        asg_vms = self.get_asg_vms()
        stopped_vms = [vm for vm in asg_vms if vm['status'] == 'stopped']
        
        if not stopped_vms:
            logger.warning("No stopped ASG VMs available to scale up")
            return False
        
        scaled = 0
        for vm in stopped_vms[:count]:
            try:
                logger.info(f"Starting VM {vm['vmid']} ({vm['name']}) on {vm['node']}")
                self.proxmox.nodes(vm['node']).qemu(vm['vmid']).status.start.post()
                scaled += 1
                
                # Wait for VM to start
                time.sleep(10)
                
            except Exception as e:
                logger.error(f"Failed to start VM {vm['vmid']}: {e}")
        
        if scaled > 0:
            self.last_scale_time = datetime.now()
            logger.info(f"Scaled up {scaled} worker node(s)")
            return True
        
        return False
    
    def scale_down(self, count: int = 1) -> bool:
        """Scale down by gracefully shutting down ASG VMs"""
        if not self._can_scale():
            logger.info("Cooldown period active, skipping scale down")
            return False
        
        asg_vms = self.get_asg_vms()
        running_vms = [vm for vm in asg_vms if vm['status'] == 'running']
        
        if not running_vms:
            logger.warning("No running ASG VMs available to scale down")
            return False
        
        scaled = 0
        for vm in running_vms[:count]:
            try:
                # Drain node first
                node_name = vm['name']
                logger.info(f"Draining Kubernetes node {node_name}")
                self._drain_node(node_name)
                
                # Shutdown VM
                logger.info(f"Shutting down VM {vm['vmid']} ({vm['name']}) on {vm['node']}")
                self.proxmox.nodes(vm['node']).qemu(vm['vmid']).status.shutdown.post()
                scaled += 1
                
                # Wait for graceful shutdown
                time.sleep(30)
                
            except Exception as e:
                logger.error(f"Failed to shutdown VM {vm['vmid']}: {e}")
        
        if scaled > 0:
            self.last_scale_time = datetime.now()
            logger.info(f"Scaled down {scaled} worker node(s)")
            return True
        
        return False
    
    def evaluate_scaling(
        self,
        cpu_scale_up: float = 70,
        cpu_scale_down: float = 30,
        memory_scale_up: float = 80,
        memory_scale_down: float = 40
    ) -> Optional[str]:
        """Evaluate if scaling is needed based on metrics"""
        metrics = self.get_cluster_metrics()
        
        if not metrics:
            return None
        
        cpu_percent = metrics.get('cpu_percent', 0)
        memory_percent = metrics.get('memory_percent', 0)
        
        # Scale up if either CPU or memory is high
        if cpu_percent >= cpu_scale_up or memory_percent >= memory_scale_up:
            logger.info(f"Scale up triggered - CPU: {cpu_percent}%, Memory: {memory_percent}%")
            return 'up'
        
        # Scale down only if both CPU and memory are low
        if cpu_percent <= cpu_scale_down and memory_percent <= memory_scale_down:
            logger.info(f"Scale down triggered - CPU: {cpu_percent}%, Memory: {memory_percent}%")
            return 'down'
        
        logger.info(f"No scaling needed - CPU: {cpu_percent}%, Memory: {memory_percent}%")
        return None
    
    def run_once(self, config: Dict):
        """Run autoscaler evaluation once"""
        logger.info("Running autoscaler evaluation")
        
        action = self.evaluate_scaling(
            cpu_scale_up=config.get('cpu_scale_up', 70),
            cpu_scale_down=config.get('cpu_scale_down', 30),
            memory_scale_up=config.get('memory_scale_up', 80),
            memory_scale_down=config.get('memory_scale_down', 40)
        )
        
        if action == 'up':
            self.scale_up(count=1)
        elif action == 'down':
            self.scale_down(count=1)
    
    def run_loop(self, config: Dict, interval: int = 60):
        """Run autoscaler in a loop"""
        logger.info(f"Starting autoscaler loop (interval: {interval}s)")
        
        while True:
            try:
                self.run_once(config)
            except Exception as e:
                logger.error(f"Error in autoscaler loop: {e}")
            
            time.sleep(interval)
    
    def _can_scale(self) -> bool:
        """Check if cooldown period has passed"""
        if self.last_scale_time is None:
            return True
        
        return datetime.now() - self.last_scale_time >= self.cooldown_period
    
    def _drain_node(self, node_name: str):
        """Drain Kubernetes node before shutdown"""
        try:
            # Mark node as unschedulable
            body = {
                "spec": {
                    "unschedulable": True
                }
            }
            self.k8s_core.patch_node(node_name, body)
            
            # Delete pods with graceful termination
            pods = self.k8s_core.list_pod_for_all_namespaces(
                field_selector=f"spec.nodeName={node_name}"
            )
            
            for pod in pods.items:
                if pod.metadata.namespace == 'kube-system':
                    continue  # Skip system pods
                
                try:
                    self.k8s_core.delete_namespaced_pod(
                        name=pod.metadata.name,
                        namespace=pod.metadata.namespace,
                        grace_period_seconds=30
                    )
                except:
                    pass
            
            logger.info(f"Node {node_name} drained successfully")
            
        except Exception as e:
            logger.error(f"Failed to drain node {node_name}: {e}")
    
    @staticmethod
    def _parse_cpu(cpu_string: str) -> float:
        """Parse CPU string to millicores"""
        if cpu_string.endswith('n'):
            return float(cpu_string[:-1]) / 1_000_000
        elif cpu_string.endswith('m'):
            return float(cpu_string[:-1])
        else:
            return float(cpu_string) * 1000
    
    @staticmethod
    def _parse_memory(memory_string: str) -> int:
        """Parse memory string to bytes"""
        units = {
            'Ki': 1024,
            'Mi': 1024**2,
            'Gi': 1024**3,
            'K': 1000,
            'M': 1000**2,
            'G': 1000**3
        }
        
        for unit, multiplier in units.items():
            if memory_string.endswith(unit):
                return int(float(memory_string[:-len(unit)]) * multiplier)
        
        return int(memory_string)


def main():
    parser = argparse.ArgumentParser(description='Proxmox Autoscaler for k3s')
    parser.add_argument('--proxmox-host', required=True, help='Proxmox host')
    parser.add_argument('--proxmox-user', required=True, help='Proxmox user')
    parser.add_argument('--proxmox-token-name', required=True, help='Proxmox token name')
    parser.add_argument('--proxmox-token-value', required=True, help='Proxmox token value')
    parser.add_argument('--cpu-scale-up', type=float, default=70, help='CPU threshold for scale up')
    parser.add_argument('--cpu-scale-down', type=float, default=30, help='CPU threshold for scale down')
    parser.add_argument('--memory-scale-up', type=float, default=80, help='Memory threshold for scale up')
    parser.add_argument('--memory-scale-down', type=float, default=40, help='Memory threshold for scale down')
    parser.add_argument('--interval', type=int, default=60, help='Evaluation interval in seconds')
    parser.add_argument('--once', action='store_true', help='Run once and exit')
    
    args = parser.parse_args()
    
    autoscaler = ProxmoxAutoscaler(
        proxmox_host=args.proxmox_host,
        proxmox_user=args.proxmox_user,
        proxmox_token_name=args.proxmox_token_name,
        proxmox_token_value=args.proxmox_token_value
    )
    
    config = {
        'cpu_scale_up': args.cpu_scale_up,
        'cpu_scale_down': args.cpu_scale_down,
        'memory_scale_up': args.memory_scale_up,
        'memory_scale_down': args.memory_scale_down
    }
    
    if args.once:
        autoscaler.run_once(config)
    else:
        autoscaler.run_loop(config, interval=args.interval)


if __name__ == '__main__':
    main()
