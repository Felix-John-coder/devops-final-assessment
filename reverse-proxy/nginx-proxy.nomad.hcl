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

     
      address = "172.22.0.1"

      check {
        name            = "https-healthcheck"
        type            = "http"
        protocol        = "https"
        tls_skip_verify = true      # self-signed cert, so skip CA validation
        path            = "/healthz"    
        interval        = "10s"
        timeout         = "2s"
      }
    }

    task "nginx-proxy" {
      driver = "docker"

      config {
        image        = "nginx-tls-proxy:local"   
        network_mode = "host"
        force_pull   = false                     

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
