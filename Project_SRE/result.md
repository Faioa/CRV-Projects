Grafana:
- X-axis: Time
- Y-axis: Number of requests per second 

### node fetchData.js `pending`:
| total | concurrency | time (s) |
|-------|-------------|----------|
| 10000 | 500         |      |


---

### node fetchData.js `writeRead`:
| total | concurrency | time (s) |
|-------|-------------|----------|
| 10000 | 500         | 37.3     |


---


### node fetchData.js `server`:
| total | concurrency | time (s) |
|-------|-------------|----------|
| 10000 | 500         | 37.3     |
| 50000 | 500         |     |