variable "image_tag" {
  type        = string
  description = "Image tag to deploy a git SHA"
}
job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count  = 1
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

      port "http" {
        static = 8080
        to = 8080
      }
    }

    service {
      name     = "nginx-service"
      port     = "http"
      provider = "consul"
      address = "host.docker.internal"

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
        image        = "ghcr.io/felix-john-coder/devops-final-assessment:${var.image_tag}"
        network_mode = "host"
        force_pull   = false

        labels {
          logging = "promtail"
          service = "nginx service"
          job = "nginx-app"
        }
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}