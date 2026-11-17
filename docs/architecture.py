"""Architecture diagrams for the DevOps final assessment.

Run:  python3 architecture.py      (needs `pip install diagrams` + Graphviz)
Outputs (PNG, same folder): pipeline.png, runtime.png, healthcheck-flow.png
"""
from diagrams import Diagram, Cluster, Edge
from diagrams.onprem.client import User
from diagrams.onprem.vcs import Github
from diagrams.onprem.ci import GithubActions
from diagrams.onprem.registry import Harbor
from diagrams.onprem.compute import Nomad
from diagrams.onprem.network import Consul, Nginx
from diagrams.onprem.container import Docker
from diagrams.onprem.logging import Loki
from diagrams.onprem.monitoring import Grafana
from diagrams.generic.compute import Rack

graph_attr = {"fontsize": "22", "pad": "0.5", "nodesep": "0.8", "ranksep": "1.2"}

# ---------------------------------------------------------------
# 1. Delivery pipeline: source -> CI -> registry -> Nomad
# ---------------------------------------------------------------
with Diagram(
    "Delivery Pipeline: Source to Running Container",
    filename="pipeline",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    developer = User("Developer")
    github = Github("GitHub repo")

    with Cluster("CI (GitHub Actions)"):
        ci = GithubActions("ci.yaml\nlint, build, push")

    registry = Harbor("GHCR\nghcr.io/felix-john-coder/\ndevops-final-assessment")

    with Cluster("Docker host (WSL2)"):
        nomad = Nomad("Nomad\n(Docker driver)")
        consul = Consul("Consul\nservice registry")
        app = Nginx("nginx-app :8080")
        proxy = Nginx("nginx-proxy :8443")

    developer >> Edge(label="git push") >> github
    github >> Edge(label="trigger") >> ci
    ci >> Edge(label="docker push") >> registry
    registry >> Edge(label="docker pull") >> nomad
    nomad >> Edge(label="run jobs") >> [app, proxy]
    nomad >> Edge(label="register service", style="dotted") >> consul

# ---------------------------------------------------------------
# 2. Runtime: request path, health checks and log path
# ---------------------------------------------------------------
with Diagram(
    "Runtime: Requests, Health Checks and Logs",
    filename="runtime",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    user = User("End User")

    with Cluster("Request path (blue)"):
        proxy = Nginx("nginx-proxy\nTLS :8443")
        app = Nginx("nginx-app\nHTTP :8080")

    consul = Consul("Consul\nhealth checks")

    with Cluster("Logging stack (red)"):
        promtail = Rack("Promtail")
        loki = Loki("Loki :3100")
        grafana = Grafana("Grafana :3000")

    user >> Edge(label="HTTPS", color="blue") >> proxy
    proxy >> Edge(label="HTTP", color="blue") >> app

    consul >> Edge(label="GET /healthz", style="dashed", color="darkgreen") >> app
    consul >> Edge(label="GET /healthz (TLS)", style="dashed", color="darkgreen") >> proxy

    app >> Edge(label="logs", color="firebrick") >> promtail
    proxy >> Edge(label="logs", color="firebrick") >> promtail
    promtail >> Edge(label="push", color="firebrick") >> loki
    grafana >> Edge(label="LogQL query", color="firebrick") >> loki

# ---------------------------------------------------------------
# 3. Why the Consul check needed address = 172.22.0.1
# ---------------------------------------------------------------
with Diagram(
    "Consul Health Check Path (Docker network vs host)",
    filename="healthcheck-flow",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
):
    with Cluster("Docker network 172.22.0.0/16"):
        consul_c = Consul("Consul container\n(runs the check)")
        nomad_c = Nomad("Nomad container\n172.22.0.4")
        gateway = Docker("Gateway 172.22.0.1\n(= the host)")

    with Cluster("Docker host (network_mode = host)"):
        app_h = Nginx("nginx-app\nlistens on host :8080")

    nomad_c >> Edge(label="registers service", style="dotted") >> consul_c
    consul_c >> Edge(label=" BEFORE: 172.22.0.4:8080 \n connection refused ", color="red", style="dashed") >> nomad_c
    consul_c >> Edge(label=" AFTER: address = 172.22.0.1 \n :8080 returns 200 OK ", color="darkgreen") >> gateway >> app_h
