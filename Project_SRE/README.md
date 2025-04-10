# Observability Project

This project leverages the infrastructure from the previous project (Kubernetes, Prometheus, etc.) to simulate various scenarios and evaluate performance limits.

## Overview

The goal is to analyze system behavior under constrained resources and varying loads, focusing on observability using Prometheus and Grafana.

### Infrastructure

- **Redis**: Implements a main/replica pattern. The main instance handles all operations, while replicas replicate data for parallel reads. Only replicas scale initially.
  - [Redis Docker Hub](https://hub.docker.com/_/redis)
- **Node.js**: A stateless server interacting with Redis main and replicas, scalable without altering behavior.
  - [Source](https://github.com/arthurescriou/redis-node)
  - [Docker Image](https://hub.docker.com/r/arthurescriou/node-redis)
- **Prometheus/Grafana**: Collects metrics from Node.js and Redis main (required), with optional Kubernetes cluster metrics. Displays via Grafana dashboards.

_Note_: React frontend is excluded from performance analysis as it serves static files.

## Scenarios

1. **Resource Limits**:
   - Containers are capped at 1 CPU and 2GB RAM (mimicking AWS EC2 specs) to simulate realistic cloud environments.
2. **Load Testing**:
   - Simulate user traffic with HTTP requests (create, request, update, delete) using provided scripts to test read/write behavior.
3. **Scaling**:
   - Observe manual or automatic pod scaling (via Kubernetes HPA) under high load, focusing on trigger conditions.

## Load Testing Scripts

Scripts are available in [loadTest](https://github.com/arthurescriou/CRV/tree/master/loadTest):

- **`server`**: Pings server without Redis interaction.
  - Args: total calls (default: 10000), concurrent calls (default: 100).
- **`writeRead`**: Performs read/write operations on Redis.
  - Args: total calls (default: 10000), concurrent calls (default: 100).
- **`pending`**: Opens server connections (requires `arthurescriou/node-redis:1.0.6`).
  - Args: concurrent calls (default: 200), response time (default: 10000ms).

### Usage

```bash
node fetchData.js server 10000 100
node fetchData.js writeRead 10000 100
node fetchData.js pending 200 10000
```

## Report
- The report contains detailed explanations of the observations from relevant scenarios with scientific charts (e.g., max load, optimal load, scaling behavior) and detailed analysis.

## Code
...