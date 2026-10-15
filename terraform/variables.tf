variable "docker_host" {
  description = "Адрес Docker, которым управляет Terraform"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "nginx_image" {
  description = "Образ nginx"
  type        = string
  default     = "nginx:stable-alpine"
}

variable "external_port" {
  description = "Нестандартный порт, на котором nginx доступен на VM"
  type        = number
  default     = 8081
}

variable "listen_ip" {
  description = "На каком адресе VM слушать порт (127.0.0.1 = не открывать наружу)"
  type        = string
  default     = "127.0.0.1"
}
