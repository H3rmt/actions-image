FROM debian:trixie

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
# Enable QEMU binfmt (persistent)
# ------------------------------------------------------------
RUN update-binfmts --enable qemu-arm && update-binfmts --enable qemu-aarch64 && update-binfmts --enable qemu-riscv64
# TODO this wont work 

# ------------------------------------------------------------
# Install Nix (single-user, daemonless)
# ------------------------------------------------------------
RUN mkdir -m 0755 /nix \
 && chown ${USERNAME}:${USERNAME} /nix

USER ${USERNAME}
WORKDIR /home/${USERNAME}

RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

ENV PATH="/home/${USERNAME}/.nix-profile/bin:${PATH}"

# ------------------------------------------------------------
# Install Rust (stable, user-local)
# ------------------------------------------------------------
RUN curl https://sh.rustup.rs -sSf \
  | sh -s -- -y --profile minimal

ENV PATH="/home/${USERNAME}/.cargo/bin:${PATH}"

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

COPY entry.sh /usr/local/bin/entry.sh
ENTRYPOINT ["/usr/local/bin/entry.sh"]
