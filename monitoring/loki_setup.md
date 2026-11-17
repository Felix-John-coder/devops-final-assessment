# Loki Log Pipeline Setup

**Stack:** Loki (log storage) + Promtail (log collection) + Grafana (log visualization and querying).

The pipeline collects NGINX access logs from Nomad-managed Docker containers, forwards them to Loki, and makes them searchable through Grafana.

## 1. Architecture and Configuration Files

| File | Purpose |
|---|---|
| `monitoring/docker-compose.yml` | Starts Loki, Promtail, and Grafana on a shared Docker network |
| `monitoring/loki-config.yml` | Configures the Loki log storage service |
| `monitoring/promtail-config.yaml` | Configures Docker log discovery, labels, and forwarding to Loki |
| `monitoring/grafana.yml` | Automatically provisions Loki as a Grafana data source |

**Log pipeline:**

`Nomad Docker Container → Promtail → Loki → Grafana`

## 2. Nomad Docker Logging Configuration

Promtail discovers containers carrying the Docker label `logging=promtail`.

The following labels are configured in the NGINX application task:

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

Apply the updated job from the repository root, adjusting the file path if necessary:

```bash
docker exec -i nomad nomad job run - < nomad/nginx.nomad.hcl
```

Nomad updates the existing job according to its deployment configuration. Check the deployment and allocation status:

```bash
docker exec -i nomad nomad job status nginx-appp
```

## 3. Starting the Monitoring Stack

Start the monitoring services:

```bash
cd monitoring
docker compose up -d
```

Verify the containers:

```bash
docker compose ps
```

Check Loki readiness:

```bash
curl http://localhost:3100/ready
```

Expected response:

```text
ready
```

Open Grafana:

`http://localhost:3000`

The initial credentials may be `admin/admin`, depending on the Compose configuration. Change the default password before using the stack beyond local assessment testing.

## 4. Log Labels

Promtail attaches labels to make logs searchable and easier to isolate.

| Label | Source | Example |
|---|---|---|
| `job` | Docker label | `nginx-app` |
| `service` | Docker label | `nginx-service` |
| `container` | Docker container name | Nomad-managed container name |
| `task` | Parsed from container name | `nginx-app` |
| `nomad_alloc_id` | Parsed from container name | Allocation UUID |
| `app` | Static Promtail pipeline label | `nginx` |

HTTP status codes are extracted at query time rather than stored as stream labels. This avoids creating unnecessary label cardinality.

## 5. Generating Test Traffic

Generate successful and unsuccessful HTTP requests to produce sample access logs:

```bash
# Successful request
curl -i http://localhost:8080/healthz

# Deliberate 404 responses
curl -i http://localhost:8080/does-not-exist
curl -i http://localhost:8080/missing-page
```

Verify that these requests appear in the NGINX access logs and are subsequently collected by Promtail.

## 6. Querying Logs in Grafana

Navigate to:

**Grafana → Explore → Loki → Code**

Select a suitable time range, such as **Last 15 minutes**, and execute the following LogQL queries.

| # | LogQL query | Purpose |
|---|---|---|
| 1 | `{job="nginx-app"}` | Retrieve all application logs |
| 2 | `{job="nginx-app"} |= "GET"` | Filter GET requests |
| 3 | `{job="nginx-app"} \| pattern \`<ip> - <_> [<_>] "<method> <uri> <_>" <status> <size> "<_>" "<agent>"\` \| status != "200"` | Identify non-200 HTTP responses |
| 4 | `{job="nginx-app", nomad_alloc_id="<allocation-id>"}` | Isolate logs from a specific allocation |
| 5 | `sum by (status) (count_over_time({job="nginx-app"} \| pattern \`<ip> - <_> [<_>] "<method> <uri> <_>" <status> <size> "<_>" "<agent>"\` [5m]))` | Count requests grouped by HTTP status over five minutes |

**Expected observations:**

- Query 1 returns collected NGINX logs.
- Query 2 filters requests containing `GET`.
- Query 3 identifies unsuccessful responses, including the deliberate 404 requests.
- Query 4 isolates logs from a particular Nomad allocation.
- Query 5 provides a count of requests grouped by HTTP status.

**Screenshot:** `docs/screenshots/grafana-explore.png`

The screenshot should show the executed query and actual returned log entries.

## 7. Troubleshooting

| Problem | Cause | Resolution |
|---|---|---|
| Nomad allocation unhealthy: `dial tcp 172.22.0.4:8080: connection refused` | Nomad registered its container IP instead of the host-reachable address used by the host-networked application | Configured `address = "172.22.0.1"` in the Consul service registration |
| `curl localhost:8080` failed inside the Consul container | `localhost` refers to the current container, not the application container or Docker host | Tested using the Docker network gateway `172.22.0.1:8080` |
| GHCR image pull failed with IPv6 `network is unreachable` | WSL did not have a working IPv6 route to the registry | Used `force_pull = false` to reuse the locally cached image where appropriate |
| Grafana returned no logs | Incorrect label selector, Promtail discovery issue, or missing test traffic | Verified Docker labels, Promtail logs, Loki readiness, and the selected Grafana time range |

