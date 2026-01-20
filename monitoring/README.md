# K3s Cluster Monitoring

This directory contains monitoring configurations and tools for the k3s cluster.

## Overview

The monitoring setup includes:
- Prometheus node exporter on all nodes
- Critical alert rules for system and cluster health
- Health dashboard for real-time monitoring
- Metrics collection and validation tools

## Components

### Node Exporter

Configured in `hosts/base-k3s-vm/configuration.nix`:
- Runs on port 9100
- Collects system metrics (CPU, memory, disk, network)
- Excludes container-specific filesystems and network interfaces

### Alert Rules

Defined in `alerts.yaml`:
- **Node alerts**: CPU, memory, disk, system load
- **Kubernetes alerts**: Node/pod health, deployments, PVCs
- **K3s alerts**: Service health, ETCD status, API latency
- **Network alerts**: Error rates, saturation
- **Security alerts**: SSH failures, certificate expiry

### Scripts

1. **health-dashboard.sh** - Real-time cluster health dashboard
   ```bash
   ./health-dashboard.sh --continuous --refresh 10
   ```

2. **test-metrics.sh** - Test metric collection from nodes
   ```bash
   ./test-metrics.sh --format json
   ```

## Deployment

### 1. Deploy Node Exporter

Node exporter is automatically deployed via NixOS configuration:
```nix
services.prometheus.exporters.node = {
  enable = true;
  port = 9100;
};
```

### 2. Deploy Prometheus

Deploy Prometheus to collect metrics:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'node'
        static_configs:
          - targets:
            - '10.10.20.11:9100'
            - '10.10.20.12:9100'
            - '10.10.20.13:9100'
```

### 3. Deploy Alert Manager

Configure Alert Manager for alert routing:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
    receivers:
      - name: 'default'
        # Configure your notification channels here
```

### 4. Apply Alert Rules

Deploy alert rules as a ConfigMap:
```bash
kubectl create configmap prometheus-alerts \
  --from-file=alerts.yaml \
  -n monitoring
```

## Testing

### Test Node Exporters
```bash
../tests/monitoring/test-exporters.sh
```

### Test Metrics Collection
```bash
./test-metrics.sh --nodes "10.10.20.11,10.10.20.12"
```

### Test Specific Metrics
```bash
# Get raw metrics from a node
curl http://10.10.20.11:9100/metrics

# Check specific metric
curl -s http://10.10.20.11:9100/metrics | grep node_memory_MemAvailable_bytes
```

## Monitoring Best Practices

1. **Resource Allocation**
   - Ensure Prometheus has sufficient storage (10GB+ recommended)
   - Monitor Prometheus's own resource usage

2. **Retention Policy**
   - Configure appropriate retention time (default: 15 days)
   - Consider long-term storage solutions (Thanos, Cortex)

3. **Alert Fatigue**
   - Start with critical alerts only
   - Tune thresholds based on your environment
   - Use inhibition rules to prevent alert storms

4. **Security**
   - Secure metrics endpoints with authentication
   - Use TLS for Prometheus scraping
   - Restrict access to monitoring namespace

## Troubleshooting

### Node Exporter Issues
```bash
# Check service status
systemctl status prometheus-node-exporter

# Check logs
journalctl -u prometheus-node-exporter -f

# Test endpoint
curl http://localhost:9100/metrics
```

### Missing Metrics
1. Verify node exporter is running
2. Check firewall rules (port 9100)
3. Confirm Prometheus can reach the node
4. Check scrape configuration

### Alert Not Firing
1. Verify alert rule syntax
2. Check metric existence
3. Review threshold values
4. Test alert rule with promtool

## Integration with Grafana

Example dashboard panels:

```json
{
  "targets": [
    {
      "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
      "legendFormat": "CPU Usage - {{instance}}"
    }
  ]
}
```

## Useful Queries

### CPU Usage
```promql
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory Usage
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Disk Usage
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

### Pod Restart Rate
```promql
rate(kube_pod_container_status_restarts_total[5m])
```