job "nginx-proxy" {
  datacenters = ["dc1"]
  type        = "service"

  group "proxy" {
    count          = 1
    shutdown_delay = "30s"

    # Rolling deployment configuration
    update {
      max_parallel      = 1
      min_healthy_time  = "10s"
      healthy_deadline  = "2m"
      auto_revert       = true
    }

    # Restart failed tasks before rescheduling
    restart {
      attempts = 3
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    # Reschedule allocations after restart attempts are exhausted
    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = false
    }

    network {
      mode = "host"

      port "https" {
        static = 8443
      }
    }

    service {
      name  = "nginx-proxy"
      port   = "https"
      provider = "consul"
      address = "host.docker.internal"

      check {
        name        = "https-healthcheck"
        type       = "http"
        protocol      = "https"
        tls_skip_verify = true
        path            = "/healthz"
        interval     = "10s"
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
