terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

provider "docker" {}

variable "litellm_master_key" {
  description = "LiteLLM Master Key for authentication"
  type        = string
  sensitive   = true
}

variable "litellm_salt_key" {
  description = "LiteLLM Salt Key for encryption"
  type        = string
  sensitive   = true
}

variable "comfyui_path1" {
  description = "Local path for ComfyUI models directory (will be mounted to /opt/comfyui/models)"
  type        = string
}

variable "comfyui_path2" {
  description = "Local path for ComfyUI custom_nodes directory (will be mounted to /opt/comfyui/custom_nodes)"
  type        = string
}

# Open WebUI Volumes
resource "docker_volume" "ollama" {
  name = "ollama"
}

resource "docker_volume" "open_webui" {
  name = "open-webui"
}

# Open WebUI Container
resource "docker_container" "open_webui" {
  name    = "open-webui"
  image   = "ghcr.io/open-webui/open-webui:ollama"
  restart = "always"

  ports {
    internal = 8080
    external = 3000
  }

  volumes {
    volume_name    = docker_volume.ollama.name
    container_path = "/root/.ollama"
  }

  volumes {
    volume_name    = docker_volume.open_webui.name
    container_path = "/app/backend/data"
  }
}

# LiteLLM Repo Cloning
resource "null_resource" "litellm_clone" {
  triggers = {
    repo_url = "https://github.com/BerriAI/litellm"
  }
  
  # Added for Mac/Unix Use
  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -d "litellm" ]; then
        git clone https://github.com/BerriAI/litellm
      fi
    EOT
    interpreter = ["/bin/sh", "-c"]
  }
}

# Create LiteLLM .env File
resource "local_file" "litellm_env" {
  depends_on = [null_resource.litellm_clone]
  filename   = "${path.module}/litellm/.env"
  content    = <<-EOT
LITELLM_MASTER_KEY=${var.litellm_master_key}
LITELLM_SALT_KEY=${var.litellm_salt_key}
EOT
}

# LiteLLM docker-compose
resource "null_resource" "litellm_compose" {
  depends_on = [
    null_resource.litellm_clone,
    local_file.litellm_env
  ]

  triggers = {
    # Commit Change Check
    env_file_hash = md5(local_file.litellm_env.content)
    env_file_path = local_file.litellm_env.filename
  }

  provisioner "local-exec" {
    command     = "docker-compose up -d"
    working_dir = "${path.module}/litellm"
  }
}

# ComfyUI Container
resource "docker_container" "comfyui" {
  name    = "comfyui"
  image   = "ghcr.io/lecode-official/comfyui-docker:latest"
  restart = "unless-stopped"

  ports {
    internal = 8188
    external = 8188
  }

  volumes {
    host_path      = var.comfyui_path1
    container_path = "/opt/comfyui/models"
  }

  volumes {
    host_path      = var.comfyui_path2
    container_path = "/opt/comfyui/custom_nodes"
  }
  
  env = [
    "USER_ID=${data.external.user_info.result.user_id}",
    "GROUP_ID=${data.external.user_info.result.group_id}"
  ]
}

# Watchtower Container
resource "docker_container" "watchtower" {
  name    = "watchtower"
  image   = "ghcr.io/nicholas-fedor/watchtower"
  restart = "unless-stopped"


  # Mount Docker for Watchtower to Monitor Open WebUI
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  command = ["--interval", "300", "open-webui"]

  depends_on = [docker_container.open_webui]
}

# Get UserID and GroupID for Mac
data "external" "user_info" {
  program = ["/bin/sh", "-c", "echo \"{\\\"user_id\\\":\\\"$(id -u)\\\",\\\"group_id\\\":\\\"$(id -g)\\\"}\""]
}

