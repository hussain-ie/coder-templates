terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~>0.12.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~>3.0.2"
    }
  }
}

data "coder_provisioner" "me" {
}

provider "docker" {
}

data "coder_workspace" "me" {
}


resource "coder_app" "novnc" {
  agent_id      = coder_agent.main.id
  display_name = "novnc"
  slug          = "novnc"
  icon          = "https://ppswi.us/noVNC/app/images/icons/novnc-192x192.png"
  url           = "http://localhost:6081"
  subdomain    = false
  share        = "owner"
  healthcheck {
    url       = "http://localhost:6081/healthz"
    interval  = 5
    threshold = 10
  }

}

# code-server
resource "coder_app" "code-server" {
  agent_id      = coder_agent.main.id
  display_name = "code-server"
  slug         = "code-server"
  icon          = "https://cdn.icon-icons.com/icons2/2107/PNG/512/file_type_vscode_icon_130084.png"
  url           = "http://localhost:13337"
  subdomain    = true
  share        = "owner"
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 2
    threshold = 10
  }
}

resource "coder_app" "jupyter"{
  agent_id     = coder_agent.main.id
  
  slug         = "jupyter"
  display_name = "JupyterLab"
  url = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  share        = "owner"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:8888/healthz"
    interval  = 5
    threshold = 10
  }

}

resource "coder_app" "filebrowser" {
  count        = 1
  agent_id     = coder_agent.main.id
  display_name = "File Browser"
  slug         = "filebrowser"
  url          = "http://localhost:4040/"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/database.svg"
  subdomain    = true
  share        = "owner"
}



resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<EOT
    echo "Starting code-server..."
    nohup code-server --auth none --port 13337 --host 0.0.0.0 &
    echo "Starting Jupyter Lab..."
    nohup jupyter lab --port=8888 --ServerApp.token=''  --ip='*' &
    echo "Starting Filebrowser..."
    nohup filebrowser --noauth --root  /home/coder --port=4040 --address=0.0.0.0 &
    echo "Starting VNC desktop..."
    nohup supervisord &
    
    EOT

  display_apps {
    vscode                 = true
    ssh_helper             = true
    port_forwarding_helper = true
  }

  metadata {
    display_name = "CPU Usage Workspace"
    interval     = 10
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
  }

  metadata {
    display_name = "RAM Usage Workspace"
    interval     = 10
    key          = "1_ram_usage"
    script       = "coder stat mem"
  }

  metadata {
    display_name = "CPU Usage Host"
    interval     = 10
    key          = "2_cpu_usage"
    script       = "coder stat cpu --host"
  }

  metadata {
    display_name = "RAM Usage Host"
    interval     = 10
    key          = "3_ram_usage"
    script       = "coder stat mem --host"
  }

  metadata {
    display_name = "GPU Usage"
    interval     = 10
    key          = "4_gpu_usage"
    script       = <<EOT
      (nvidia-smi 1> /dev/null 2> /dev/null) && (nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{printf "%s%%", $1}') || echo "N/A"
    EOT
  }

  metadata {
    display_name = "GPU Memory Usage"
    interval     = 10
    key          = "5_gpu_memory_usage"
    script       = <<EOT
      (nvidia-smi 1> /dev/null 2> /dev/null) && (nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits | awk '{printf "%s%%", $1}') || echo "N/A"
    EOT
  }

  metadata {
    display_name = "Disk Usage"
    interval     = 600
    key          = "6_disk_usage"
    script       = "coder stat disk $HOME"
  }

  metadata {
    display_name = "Word of the Day"
    interval     = 86400
    key          = "5_word_of_the_day"
    script       = <<EOT
      curl -o - --silent https://www.merriam-webster.com/word-of-the-day 2>&1 | awk ' $0 ~ "Word of the Day: [A-z]+" { print $5; exit }'
    EOT
  }

}




resource "docker_network" "private_network" {
  name = "network-${data.coder_workspace.me.id}"
}

resource "docker_container" "dind" {
  image      = "docker:dind"
  privileged = true
  gpus = "all"
  name       = "dind-${data.coder_workspace.me.id}"
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375"]
  networks_advanced {
    name = docker_network.private_network.name
  }
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}-root"
}

resource "docker_image" "coder_image" {
  name = "desktop-pytorch"
  build {
    context ="./images/"
    dockerfile = "desktop-pytorch.Dockerfile"
    tag        = ["coder-desktop-pytorch:v0.3"]
  }

  # Keep alive for other workspaces to use upon deletion
  keep_locally = true
}

resource "docker_container" "workspace" {
  count   = data.coder_workspace.me.start_count
  image = docker_image.coder_image.name
  gpus = "all"
  name    = "coder-${data.coder_workspace.me.id}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = lower(data.coder_workspace.me.name)

  command = ["sh", "-c", coder_agent.main.init_script]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "DOCKER_HOST=${docker_container.dind.name}:2375"
  ]
  networks_advanced {
    name = docker_network.private_network.name
  }
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
}
