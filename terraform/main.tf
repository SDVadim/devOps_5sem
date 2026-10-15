terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }
}

# подключил терраформ к docker на VM
provider "docker" {
  host = var.docker_host
}

# сделал отдельную сеть
resource "docker_network" "nginx" {
  name = "tf_nginx_net"
}

# сделал том под файлы сайта
resource "docker_volume" "nginx_html" {
  name = "tf_nginx_html"
}

# скачал образ nginx
resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

# запустил nginx в своей сети, с томом и на порту 8081
resource "docker_container" "nginx" {
  name    = "tf_nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.nginx.name
  }

  mounts {
    type   = "volume"
    source = docker_volume.nginx_html.name
    target = "/usr/share/nginx/html"
  }

  ports {
    internal = 80
    external = var.external_port
    ip       = var.listen_ip
  }
}

# вывел адрес, по которому стучаться curl
output "url" {
  value = "http://${var.listen_ip}:${var.external_port}"
}
