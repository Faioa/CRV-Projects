# Prometheus Queries

## Performance Metrics (node-redis, redis, redis-replica)

### Number of Requests per Second

- `rate(http_requests_total{app="node-redis"}[5m])`: HTTP request rate of `node-redis` (req/s).
- `rate(redis_commands_total{instance="redis.default.svc.cluster.local:9121"}[5m])`: Redis command rate on `redis` (commands/s).
- `rate(redis_commands_total{instance="redis-replica.default.svc.cluster.local:9121"}[5m])`: Redis command rate on `redis-replica` (commands/s).

### Latency (Waiting Time for Completion of Request)

- `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="node-redis"}[5m]))`: HTTP request latency (P95, seconds) for `node-redis`.
- `histogram_quantile(0.95, rate(redis_command_duration_seconds{instance="redis.default.svc.cluster.local:9121"}[5m]))`: Redis command latency (P95, seconds) on `redis`.
- `histogram_quantile(0.95, rate(redis_command_duration_seconds{instance="redis-replica.default.svc.cluster.local:9121"}[5m]))`: Redis command latency (P95, seconds) on `redis-replica`.

### System Errors

- `rate(http_requests_total{app="node-redis", status=~"5.."}[5m])`: HTTP 5xx error rate for `node-redis` (req/s).
- `rate(redis_errors_total{instance="redis.default.svc.cluster.local:9121"}[5m])`: Redis error rate on `redis` (errors/s).
- `rate(redis_errors_total{instance="redis-replica.default.svc.cluster.local:9121"}[5m])`: Redis error rate on `redis-replica` (errors/s).

## Resource Usage (node-redis, redis, redis-replica)

### CPU Usage (Limits/Requests)

- `kube_pod_container_resource_limits{resource="cpu", pod=~"node-redis.*"}`: CPU limits of `node-redis` pods (cores).
- `kube_pod_container_resource_requests{resource="cpu", pod=~"node-redis.*"}`: CPU requests of `node-redis` pods (cores).
- `kube_pod_container_resource_limits{resource="cpu", pod=~"redis-[0-9]+"}`: CPU limits of `redis` pods (cores).
- `kube_pod_container_resource_limits{resource="cpu", pod=~"redis-replica-[0-9]+"}`: CPU limits of `redis-replica` pods (cores).

### Memory Usage (Limits/Requests)

- `kube_pod_container_resource_limits{resource="memory", pod=~"node-redis.*"}`: Memory limits of `node-redis` pods (bytes).
- `kube_pod_container_resource_requests{resource="memory", pod=~"node-redis.*"}`: Memory requests of `node-redis` pods (bytes).
- `kube_pod_container_resource_limits{resource="memory", pod=~"redis-[0-9]+"}`: Memory limits of `redis` pods (bytes).
- `kube_pod_container_resource_limits{resource="memory", pod=~"redis-replica-[0-9]+"}`: Memory limits of `redis-replica` pods (bytes).

### Pod Termination Status (Indirect Resource Check)

- `kube_pod_container_status_terminated_reason{pod=~"node-redis.*"}`: Reason for `node-redis` pod termination (e.g., OOMKilled).
- `kube_pod_container_status_terminated_reason{pod=~"redis-[0-9]+"}`: Reason for `redis` pod termination.
- `kube_pod_container_status_terminated_reason{pod=~"redis-replica-[0-9]+"}`: Reason for `redis-replica` pod termination.

## Autoscaling (node-redis)

### Number of Pods

- `sum(kube_pod_status_phase{pod=~"node-redis.*", phase="Running"}) by (pod)`: Running `node-redis` pods by pod name.

### HPA Metrics

- `kube_horizontalpodautoscaler_status_desired_replicas{hpa="node-redis-autoscaler"}`: Desired replicas from HPA.
- `kube_horizontalpodautoscaler_status_current_replicas{hpa="node-redis-autoscaler"}`: Current replicas from HPA.
- `kube_horizontalpodautoscaler_spec_target_metric{hpa="node-redis-autoscaler", metric_name="cpu"}`: CPU utilization used by HPA for scaling.

## Additional Metrics (Optional)

### Redis Connections

- `redis_connected_clients{instance="redis.default.svc.cluster.local:9121"}`: Number of clients connected to `redis`.
- `redis_connected_clients{instance="redis-replica.default.svc.cluster.local:9121"}`: Number of clients connected to `redis-replica`.

### Pod Error State

- `sum(kube_pod_status_phase{pod=~"node-redis.*", phase=~"Failed|Error"}) by (pod)`: Count `node-redis` pods in error state.


===

Per Service (node-redis, redis, redis-replica, ingress controller ?, Node-exporter ?, metallb ?) :

- Nb of pods
- CPU usage
- Memory usage
- Nb request per second
  (- Waiting time for completion of request)
- System errors
