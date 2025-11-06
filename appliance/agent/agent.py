#!/usr/bin/env python3
"""
AIOps Appliance Agent

Phone-home agent that runs on each Raspberry Pi appliance.
Handles heartbeat, config sync, metrics export, and task execution.
"""
import asyncio
import httpx
import json
import logging
import os
import platform
import psutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, List
import yaml


# =============================================================================
# Configuration
# =============================================================================

class Config:
    """Agent configuration loaded from YAML file"""

    def __init__(self, config_path: str = "/etc/aiops/agent.yml"):
        self.config_path = config_path
        self.config = self._load_config()

    def _load_config(self) -> Dict:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            logging.warning(f"Config file not found: {self.config_path}, using defaults")
            return self._default_config()

    def _default_config(self) -> Dict:
        """Default configuration for development"""
        return {
            "backend": {
                "url": os.getenv("BACKEND_URL", "http://localhost:8000"),
                "api_key": os.getenv("API_KEY", "dev-key-123"),
                "timeout": 30
            },
            "appliance": {
                "id": os.getenv("APPLIANCE_ID", "dev-appliance-001"),
                "name": platform.node()
            },
            "heartbeat": {
                "interval": 60  # seconds
            },
            "config_sync": {
                "interval": 300  # 5 minutes
            },
            "services": ["dns", "samba", "mail", "pki"],
            "logging": {
                "level": "INFO",
                "file": "/var/log/aiops-agent.log"
            }
        }

    @property
    def backend_url(self) -> str:
        return self.config["backend"]["url"]

    @property
    def api_key(self) -> str:
        return self.config["backend"]["api_key"]

    @property
    def appliance_id(self) -> str:
        return self.config["appliance"]["id"]

    @property
    def heartbeat_interval(self) -> int:
        return self.config["heartbeat"]["interval"]

    @property
    def config_sync_interval(self) -> int:
        return self.config["config_sync"]["interval"]

    @property
    def services(self) -> List[str]:
        return self.config["services"]


# =============================================================================
# Agent
# =============================================================================

class ApplianceAgent:
    """Main agent that manages appliance operations"""

    def __init__(self, config: Config):
        self.config = config
        self.client = httpx.AsyncClient(
            base_url=config.backend_url,
            timeout=config.config["backend"]["timeout"],
            headers={
                "Authorization": f"Bearer {config.api_key}",
                "User-Agent": f"AIOps-Agent/1.0 (Appliance {config.appliance_id})"
            }
        )
        self.running = False
        self.version = "1.0.0"

    async def start(self):
        """Start the agent"""
        self.running = True
        logging.info(f"Starting AIOps Agent v{self.version}")
        logging.info(f"Appliance ID: {self.config.appliance_id}")
        logging.info(f"Backend URL: {self.config.backend_url}")

        # Start background tasks
        tasks = [
            asyncio.create_task(self.heartbeat_loop()),
            asyncio.create_task(self.config_sync_loop()),
        ]

        try:
            await asyncio.gather(*tasks)
        except asyncio.CancelledError:
            logging.info("Agent tasks cancelled")
        finally:
            await self.client.aclose()

    async def stop(self):
        """Stop the agent"""
        self.running = False
        logging.info("Stopping agent...")

    # =========================================================================
    # Heartbeat
    # =========================================================================

    async def heartbeat_loop(self):
        """Send heartbeat to backend periodically"""
        while self.running:
            try:
                await self.send_heartbeat()
            except Exception as e:
                logging.error(f"Heartbeat failed: {e}")

            await asyncio.sleep(self.config.heartbeat_interval)

    async def send_heartbeat(self):
        """Send heartbeat with status and metrics"""
        heartbeat_data = {
            "appliance_id": self.config.appliance_id,
            "version": self.version,
            "uptime": self.get_uptime(),
            "services": self.get_service_status(),
            "metrics": self.get_metrics()
        }

        try:
            response = await self.client.post(
                "/api/v1/heartbeat",
                json=heartbeat_data
            )
            response.raise_for_status()

            logging.debug(f"Heartbeat sent: {response.json()}")

        except httpx.HTTPError as e:
            logging.error(f"Failed to send heartbeat: {e}")
            raise

    def get_uptime(self) -> int:
        """Get system uptime in seconds"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.readline().split()[0])
                return int(uptime_seconds)
        except:
            return 0

    def get_service_status(self) -> Dict[str, str]:
        """Get status of all services"""
        status = {}

        for service in self.config.services:
            # Map service names to systemd service names
            service_map = {
                "dns": "dnsmasq",
                "samba": "smbd",
                "mail": "postfix",
                "pki": "step-ca"
            }

            systemd_service = service_map.get(service, service)
            status[service] = self.check_service_status(systemd_service)

        return status

    def check_service_status(self, service_name: str) -> str:
        """Check if a systemd service is running"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", service_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout.strip()  # "active", "inactive", "failed", etc.
        except Exception as e:
            logging.warning(f"Failed to check service {service_name}: {e}")
            return "unknown"

    def get_metrics(self) -> Dict[str, float]:
        """Get resource usage metrics"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            mem = psutil.virtual_memory()
            disk = psutil.disk_usage('/')

            return {
                "cpu_percent": cpu_percent,
                "mem_percent": mem.percent,
                "mem_used_mb": mem.used / (1024 * 1024),
                "disk_percent": disk.percent,
                "disk_used_gb": disk.used / (1024 * 1024 * 1024)
            }
        except Exception as e:
            logging.error(f"Failed to get metrics: {e}")
            return {}

    # =========================================================================
    # Configuration Sync
    # =========================================================================

    async def config_sync_loop(self):
        """Pull configuration updates from backend periodically"""
        while self.running:
            try:
                await self.sync_config()
            except Exception as e:
                logging.error(f"Config sync failed: {e}")

            await asyncio.sleep(self.config.config_sync_interval)

    async def sync_config(self):
        """Fetch and apply configuration from backend"""
        try:
            response = await self.client.get(
                f"/api/v1/appliance/{self.config.appliance_id}/config"
            )
            response.raise_for_status()

            config_data = response.json()
            logging.info(f"Received config update: {len(config_data)} items")

            # Apply configuration
            await self.apply_config(config_data)

        except httpx.HTTPError as e:
            logging.error(f"Failed to sync config: {e}")
            raise

    async def apply_config(self, config: Dict):
        """Apply configuration received from backend"""
        # TODO: Implement actual configuration application

        # Examples:
        # - Update DNS zones → write to /etc/dnsmasq.d/
        # - Update Samba shares → write to /etc/samba/smb.conf
        # - Update users → run useradd/usermod
        # - Update SSL certs → write to /etc/ssl/

        logging.info(f"Applying configuration (placeholder)")

        # For now, just log what we would do
        if "dns_zones" in config:
            logging.info(f"Would update {len(config['dns_zones'])} DNS zones")

        if "samba_shares" in config:
            logging.info(f"Would update {len(config['samba_shares'])} Samba shares")

        if "users" in config:
            logging.info(f"Would update {len(config['users'])} users")


# =============================================================================
# Main
# =============================================================================

def setup_logging(config: Config):
    """Setup logging configuration"""
    log_level = getattr(logging, config.config["logging"]["level"])
    log_file = config.config["logging"]["file"]

    # Create log directory if it doesn't exist
    log_dir = Path(log_file).parent
    log_dir.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_file)
        ]
    )


async def main():
    """Main entry point"""
    # Load configuration
    config_path = os.getenv("AGENT_CONFIG", "/etc/aiops/agent.yml")
    config = Config(config_path)

    # Setup logging
    setup_logging(config)

    # Create and start agent
    agent = ApplianceAgent(config)

    try:
        await agent.start()
    except KeyboardInterrupt:
        logging.info("Received interrupt signal")
    finally:
        await agent.stop()


if __name__ == "__main__":
    asyncio.run(main())
