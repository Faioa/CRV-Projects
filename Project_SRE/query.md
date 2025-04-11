```query
rate(http_requests_total[5m])
  - rate(http_requests_total{method="GET"}[5m]) : Request GET (/second).
  - rate(http_requests_total{method="POST"}[5m]) : Request POST (/second).
  - rate(http_requests_total{status=~"5.."}[5m]) : Request HTTP 5xx (/second).

rate(redis_commands_total{instance="redis.default.svc.cluster.local:9121"}[5m])

rate(redis_commands_total{instance="redis-replica.default.svc.cluster.local:9121"}[5m])

redis_connected_clients{instance="redis.default.svc.cluster.local:9121"}

redis_connected_clients{instance="redis-replica.default.svc.cluster.local:9121"}

redis_memory_used_bytes{instance="redis.default.svc.cluster.local:9121"}

redis_memory_used_bytes{instance="redis-replica.default.svc.cluster.local:9121"}  
```



=== kube ===

kube_pod_info{pod=~"node-redis.*"}
: Đếm số pod node-redis đang chạy.

sum(kube_pod_status_phase{pod=~"node-redis.*", phase="Running"}) by (pod)
: Hiển thị số pod node-redis đang chạy theo thời gian, để thấy autoscaling.

kube_hpa_status_desired_replicas{hpa="node-redis-autoscaler"}
: Hiển thị số pod mong muốn (desired) từ HPA.

kube_hpa_status_current_replicas{hpa="node-redis-autoscaler"}
: Hiển thị số pod hiện tại (actual) từ HPA.

kube_hpa_spec_target_metric{hpa="node-redis-autoscaler", metric_name="cpu"}
: Đo CPU utilization mà HPA dùng để quyết định scale.
