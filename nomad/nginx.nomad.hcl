job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count  = 1
    shutdown_delay = "30s"

    network {
      mode = "host"

      port "http" {
        static = 8080
      }
    }

    service {
      name     = "nginx-service"
      port     = "http"
      provider = "consul"
      address = "172.22.0.1"

      check {
        name     = "healthcheck"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx-container" {
      driver = "docker"

      config {
        image        = "ghcr.io/felix-john-coder/devops-final-assessment:latest"
        network_mode = "host"
        force_pull   = false

        labels {
          logging = "promtail"
          service = "nginx service"
          job = "nginx-app"
        }
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}