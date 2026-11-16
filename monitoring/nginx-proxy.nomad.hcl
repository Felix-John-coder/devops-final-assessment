job "nginx-proxy" {
  datacenters = ["dc1"]
  type        = "service"

  group "proxy" {
    count          = 1
    shutdown_delay = "30s"

    network {
      mode = "host"

      port "https" {
        static = 8443
      }
    }

    service {
      name     = "nginx-proxy"
      port     = "https"
      provider = "consul"

      # Same fix as nginx-app: the address Consul (in its container) uses
      # to reach the host.
      address = "172.22.0.1"

      check {
        name            = "https-healthcheck"
        type            = "http"
        protocol        = "https"
        tls_skip_verify = true          # self-signed cert, so skip CA validation
        path            = "/healthz"    # passes through the proxy to the app
        interval        = "10s"
        timeout         = "2s"
      }
    }

    task "nginx-proxy" {
      driver = "docker"

      config {
        image        = "nginx-tls-proxy:local"   # built locally, see steps
        network_mode = "host"
        force_pull   = false                     # local image, nothing to pull

        # Lets Promtail ship the proxy's access logs too.
        labels = {
          logging = "promtail"
          service = "nginx-proxy"
          job     = "nginx-proxy"
        }
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
