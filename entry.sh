#!/usr/bin/env bash
set -e

sudo update-binfmts --enable qemu-arm
sudo update-binfmts --enable qemu-aarch64
sudo update-binfmts --enable qemu-riscv64

rustup default stable

exec "$@"
