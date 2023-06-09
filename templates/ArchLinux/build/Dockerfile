# Arch Linux (Rolling)
FROM docker.io/library/archlinux:latest

SHELL ["/bin/bash", "-c"]

USER 0

# Install needed packages
RUN pacman -Syyu --noconfirm --quiet --noprogressbar \
      ca-certificates curl wget openssh \
      base-devel git man-db man-pages \
      neovim \
      pyenv \
      bash zsh zsh-autosuggestions starship && \

    # Delete package cache to avoid consuming space in layer
    pacman -Scc

# Add a user `coder` so that you're not developing as the `root` user
RUN useradd coder \
      --create-home \
      --shell=/bin/zsh \
      --uid=1000 \
      --user-group
RUN echo coder:coder | chpasswd

# Workspace
RUN mkdir /home/coder/workspace && ln -s /home/coder/workspace /workspace && chown coder:coder /workspace

USER 1000

# Shell
RUN mkdir -p /home/coder/.config
RUN curl -fsSL https://raw.githubusercontent.com/wvffle/coder-config/master/resources/zshrc > /home/coder/.zshrc
RUN curl -fsSL https://raw.githubusercontent.com/wvffle/coder-config/master/resources/starship.toml > /home/coder/.config/starship.toml

# Install Python using PyEnv
RUN pyenv install -s 3 && pyenv global 3
RUN /home/coder/.pyenv/shims/pip install -I poetry

# Install Rust using Rustup
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# Install Nodejs using NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
RUN . $HOME/.nvm/nvm.sh && nvm install --lts

# Now install code-server
RUN wget https://code-server.dev/install.sh -P /home/coder/ && \
    chmod +x /home/coder/install.sh && \
    /home/coder/install.sh --method standalone && \
    rm /home/coder/install.sh

