# Longhorn Storage Operations

Longhorn provides replicated, highly available persistent storage for our Proxmox VMs, which is critical for components like Vault Raft Storage and Prometheus/Loki blocks.

## Default Configuration

- **Replicas**: 3 per volume (ensures quorum even if a node goes down)
- **Auto Balance**: Best-effort replica distribution
- **Fast Rebuild**: Enabled to quickly recreate replicas on healthy nodes

## Monitoring Replica Rebuilds & Alerts

When a Proxmox VM goes down or needs maintenance, Longhorn will automatically detect missing replicas. 

1. **Dashboard Check**: Access Longhorn UI via `kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80`.
2. check the `Volume` page; it will show volumes degrading from `Healthy` to `Degraded`.
3. If the node is gone for more than the expected eviction time, Longhorn will rebuild missing replicas onto any available node in the cluster.

> [!TIP]  
> If you have Prometheus deployed via kube-prometheus-stack, you can apply the ServiceMonitor included in the Longhorn chart to scrape metrics. Key alerts to create in Grafana:
> - `LonghornVolumeDegraded` (A volume has lost at least one replica)
> - `LonghornNodeDown` (A storage node has disconnected)
