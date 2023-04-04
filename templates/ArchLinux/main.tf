# Parameters
data "coder_parameter" "dotfiles_url" {
  name        = "Dotfiles URL"
  description = "Dotfiles repo URL (see https://dotfiles.github.io)"
  mutable     = true
  default     = ""
}

data "coder_parameter" "code_server_sharing" {
  name        = "Sharing"
  description = "Who has the access to the Web IDE?"
  icon        = "/emojis/1f512.png"
  type        = "string"
  default     = "owner"

  option {
    name = "Only me"
    value = "owner"
    icon = "/emojis/1f512.png"
  }

  option {
    name = "Authenticated users"
    value = "authenticated"
    icon = "/emojis/1f464.png"
  }

  option {
    name = "Everybody (DANGER)"
    value = "public"
    icon = "/emojis/1f480.png"
  }
}

# Terraform stuff
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.6.17"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

# Coder stuff
locals {
  username = data.coder_workspace.me.owner
}

data "coder_provisioner" "me" {
}

provider "docker" {
}

data "coder_workspace" "me" {
}

# Startup script
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<EOF
    #!/bin/sh

    # Start code-server
    /home/coder/.local/bin/code-server \
    	--disable-telemetry \
	    --disable-workspace-trust \
    	--auth none \
	    --port 13337 &

    # Source the dotfiles
    coder dotfiles -y ${data.coder_parameter.dotfiles_url.value} &
  EOF

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
  }
}

# Docker stuff
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "./build"
    build_args = {
      USER = local.username
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "../../resources/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

# Code Server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/workspace"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = data.coder_parameter.code_server_sharing.value

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}