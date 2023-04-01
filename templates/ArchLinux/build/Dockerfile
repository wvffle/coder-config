# Arch Linux (Rolling)
FROM docker.io/library/archlinux:latest

SHELL ["/bin/bash", "-c"]

USER 0

# Install needed packages
RUN pacman -Syyu --noconfirm --quiet --noprogressbar \
      bash \
      ca-certificates \
      curl \
      wget \
      gcc \
      base-devel \
      gcc \
      make \
      git \
      neovim \
      pyenv && \
    # Delete package cache to avoid consuming space in layer
    pacman -Scc

# Add a user `coder` so that you're not developing as the `root` user
RUN useradd coder \
      --create-home \
      --shell=/bin/bash \
      --uid=1000 \
      --user-group


RUN curl -fsSL https://raw.githubusercontent.com/wvffle/coder-config/master/resources/bashrc > /home/coder/.bashrc && \
    chown coder /home/coder/.bashrc

USER 1000

# Install Rust using Rustup
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install Nodejs using NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash && \
	. $NVM_DIR/nvm.sh && \
	nvm install --lts

# Now install code-server
RUN wget https://code-server.dev/install.sh -P /home/coder/ && \
    chmod +x /home/coder/install.sh && \
    /home/coder/install.sh --method standalone && \
    rm /home/coder/install.sh

