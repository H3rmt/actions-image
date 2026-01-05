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
    curl \
    git \
    sudo \
    xz-utils \
    build-essential \
    pkg-config \
    clang \
    lld \
    qemu-user-static \
    binfmt-support \
    && rm -rf /var/lib/apt/lists/*

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

COPY entry.sh /usr/local/bin/entry.sh
ENTRYPOINT ["/usr/local/bin/entry.sh"]
