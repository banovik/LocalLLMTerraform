# Automatic Local LLM Deployment

This Terraform configuration creates four different Docker containers with the purpose of deploying your own highly-capable local LLM service. The four containers are as follows:

1. **Open WebUI** - This is your AI chat GUI. The image used contains native integrated Ollama support, allowing you to download and use models directly from Ollama.
2. **LiteLLM** - This service allows you to connect to cloud LLMs via their API. It is not needed, but can improve the functionality of Open WebUI, allowing you to query all your LLMs from one central location.
3. **ComfyUI** - This is an image generation engine. It connects to Open WebUI via an OpenAPI key and then allows you to generate and display images directly in Open WebUI.
4. **Watchtower** - This is a service meant to keep the Open WebUI container up-to-date. It regularly checks whether the Open WebUI version is current, and will update it as needed.

## Prerequisites

You must have the following programs installed:

- Terraform
- Docker Desktop or Docker Engine
- Docker Compose
- Git

Additionally, if you want to utilize your GPU for the LLMs and image generator, you will need to have your NVIDIA GPU support correctly configured.

## Setup

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Configure Variables**:
   - Copy `terraform.tfvars.example` to `terraform.tfvars`
   - Edit `terraform.tfvars` and replace the defaults with your desired values.
     - `litellm_master_key`: Your LiteLLM master key
     - `litellm_salt_key`: Your LiteLLM salt key
     - `comfyui_path1`: Local path for ComfyUI models directory
     - `comfyui_path2`: Local path for ComfyUI custom_nodes directory

3. **Apply Configuration**:
   ```bash
   terraform apply
   ```

## Deployment Defaults

### Open WebUI
- **Local Port**: 3000 (mapped to Container Port 8080)
- **Volumes**: 
  - `ollama` volume used to store locally downloaded Ollama models
  - `open-webui` volume used to store application data
- **GPU**: NVIDIA GPU support enabled
- **Access**: http://localhost:3000

### LiteLLM
- **Local Port**: 4000 (mapped to Container Port 4000)
- **Volumes**: 
  - `litellm_postgres_data` volume used to store Postgres data across restarts
  - `litellm_prometheus_data` volume used to store monitoring data
**Access**: http://localhost:4000

### ComfyUI
- **Local Port**: 8188 (mapped to Container Port 8188)
- **Volumes**: 
  - Models directory (in the user-defined `path1` variable)
  - Custom nodes directory (in the user-defined `path2` variable)
- **GPU**: NVIDIA GPU support enabled
- **Access**: http://localhost:8188

## Destroying Resources

To remove all deployed containers and volumes enter the following command:

```bash
terraform destroy
```

**Note**: This will remove the Docker containers and volumes, but will not delete the cloned `litellm` directory or your local ComfyUI model and custom_nodes directories or their contents.