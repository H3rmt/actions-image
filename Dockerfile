FROM debian:testing

ARG USERNAME=user
ARG UID=1001
ARG GID=1001

ENV DEBIAN_FRONTEND=noninteractive
ENV NIX_CONFIG="experimental-features = nix-command flakes"

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl git jq sudo xz-utils build-essential pkg-config sed zip unzip just wget \
    clang lld make tar zstd \
    qemu-user qemu-user-binfmt \
    && rm -rf /var/lib/apt/lists/*

# Github Cli
RUN sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

# ------------------------------------------------------------
# Create non-root user
# ------------------------------------------------------------
RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME} \
 && usermod -aG sudo ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}

# ------------------------------------------------------------
# Install Nix (single-user, daemonless)
# ------------------------------------------------------------
RUN mkdir -m 0755 /nix \
 && chown ${USERNAME}:${USERNAME} /nix

USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

RUN nix-env -iA cachix -f https://cachix.org/api/v1/install

# ------------------------------------------------------------
# Install Rust (stable, user-local)
# ------------------------------------------------------------
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 

ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

RUN rustup install stable && rustup target add x86_64-unknown-linux-gnu && rustup default stable

# ------------------------------------------------------------
# Sanity checks (fail build if broken)
# ------------------------------------------------------------
RUN nix --version \
 && rustc --version \
 && cargo --version \
 && qemu-aarch64 --version

# ------------------------------------------------------------
# GitHub Actions requirements
# ------------------------------------------------------------
# Actions expect HOME to be writable
ENV HOME=/home/${USERNAME}
ENV USER=user
