```query
rate(http_requests_total[5m])
  - rate(http_requests_total{method="GET"}[5m]) : Request GET (/second on last 5min).
  - rate(http_requests_total{method="POST"}[5m]) : Request POST (/second on last 5min).
  - rate(http_requests_total{status=~"5.."}[5m]) : Request HTTP 5xx (/second on last 5min).

rate(redis_commands_total{instance="redis.default.svc.cluster.local:9121"}[5m])

rate(redis_commands_total{instance="redis-replica.default.svc.cluster.local:9121"}[5m])

redis_connected_clients{instance="redis.default.svc.cluster.local:9121"}

redis_connected_clients{instance="redis-replica.default.svc.cluster.local:9121"}

redis_memory_used_bytes{instance="redis.default.svc.cluster.local:9121"}

redis_memory_used_bytes{instance="redis-replica.default.svc.cluster.local:9121"}  
```

Per Service (node-redis, redis, redis-replica, ingress controller ?, Node-exporter ?, metallb ?) :
- Nb of pods
- CPU usage
- Memory usage
- Nb request per second
(- Waiting time for completion of request)
- System errors

