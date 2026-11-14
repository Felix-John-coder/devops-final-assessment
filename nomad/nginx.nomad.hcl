
job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "nginx" {
    count = 1

    network {
      port "http" {
        from = 8080
        to = 8080
      }
    }

    task "nginx-container" {
      driver = "docker"

      config {
        image = "ghcr.io/felix-john-coder/devops-final-assessment:latest"
        ports = ["http"]
        force_pull = true
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
