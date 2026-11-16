# Loki Log Pipeline Setup

Stack: **Loki** (log storage) + **Promtail** (log shipper) + **Grafana** (query UI),
shipping NGINX logs from a Nomad-managed Docker container.

## 1. Files

| File | Purpose |
|---|---|
| `monitoring/docker-compose.yaml` | Starts Loki, Promtail, Grafana on one shared network |
| `monitoring/loki-config.yaml` | Loki server config (committed, mounted into the container) |
| `monitoring/promtail-config.yaml` | Discovers containers, attaches labels, pushes to Loki |
| `monitoring/grafana-datasource.yaml` | Auto-registers Loki as a Grafana data source |

## 2. Required change to the Nomad job

Promtail only ships containers that carry the Docker label `logging=promtail`.
Add `labels` to the task config in `nginx.nomad.hcl`:

```hcl
config {
  image        = "ghcr.io/felix-john-coder/devops-final-assessment:latest"
  network_mode = "host"
  force_pull   = false
  labels = {
    logging = "promtail"
    job     = "nginx-app"
    service = "nginx-service"
  }
}
```

Then redeploy: `nomad job stop nginx-app && nomad job run nginx.nomad.hcl`.

## 3. How the stack was started

```sh
cd monitoring
docker compose up -d
docker compose ps          # all three should be "running"
```

- Loki ready check: `curl http://localhost:3100/ready` (returns `ready`)
- Grafana: http://localhost:3000 (admin / admin)

## 4. Label set

| Label | Source | Example |
|---|---|---|
| `job` | Docker label `job` (set in Nomad job) | `nginx-app` |
| `service` | Docker label `service` | `nginx-service` |
| `container` | Docker container name | `nginx-container-<alloc-id>` |
| `task` | Parsed from container name | `nginx-container` |
| `nomad_alloc_id` | Parsed from container name (Nomad names containers `<task>-<alloc-uuid>`) | `3f1a...` |
| `app` | Static label in Promtail pipeline | `nginx` |

HTTP status is not a label on purpose (high cardinality). It is extracted at query time.

## 5. Generating test traffic

```sh
curl -i http://localhost:8080/healthz          # 200
curl -i http://localhost:8080/does-not-exist   # 404 (deliberate)
curl -i http://localhost:8080/missing-page     # 404 (deliberate)
```

## 6. LogQL queries and results

> Fill in the Result column from your own Grafana Explore run, then add the screenshot.

| # | Query | Purpose | Result |
|---|---|---|---|
| 1 | `{job="nginx-app"}` | All nginx logs arrive | _(paste what you saw)_ |
| 2 | `{job="nginx-app"} \|= "GET"` | Only access-log lines | _(paste)_ |
| 3 | ``{job="nginx-app"} \| pattern `<ip> - <_> [<_>] "<method> <uri> <_>" <status> <size> "<_>" "<agent>"` \| status != "200"`` | Non-200 requests | _(expect the 404 lines for `/does-not-exist`)_ |
| 4 | `{job="nginx-app", nomad_alloc_id="<id>"}` | Isolate one allocation | _(paste)_ |
| 5 | `sum by (status) (count_over_time({job="nginx-app"} \| pattern `<_> - <_> [<_>] "<_> <_> <_>" <status> <_> "<_>" "<_>"` [5m]))` | Requests per status code | _(paste)_ |

Screenshot: `docs/screenshots/grafana-explore.png`

## 7. Problems hit and fixes

| Problem | Cause | Fix |
|---|---|---|
| Nomad showed the allocation unhealthy; Consul check error `dial tcp 172.22.0.4:8080: connection refused` | nginx runs with `network_mode = "host"`, but Nomad registered `172.22.0.4` (not the host), where nothing listens on 8080 | Added `address = "172.22.0.1"` (Docker network gateway = host) to the `service` block |
| `curl localhost:8080` failed inside the Consul container | `localhost` inside a container is the container itself | Tested the gateway IP `172.22.0.1:8080` instead (returned 200) |
| Image pull failed: `dial tcp [2606:...]:443: network is unreachable` | Docker tried IPv6 to ghcr.io and WSL has no IPv6 route | Set `force_pull = false` to use the local image, or disabled IPv6 via sysctl |
| _(add any problems from the Loki setup here)_ | | |
