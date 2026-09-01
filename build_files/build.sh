#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

dnf5 install -y nix nix-daemon

# `/` is immutable, therefore we need to bind mount `/nix` to `/var/nix`
# so that the Nix daemon can write to it.
mkdir -p /var/nix

semanage fcontext -a -t usr_t '/nix/store(/.*)?'
semanage fcontext -a -t usr_t '/var/nix/store(/.*)?'
semanage fcontext -a -t var_run_t '/nix/var/nix/daemon-socket(/.*)?'
semanage fcontext -a -t var_run_t '/var/nix/var/nix/daemon-socket(/.*)?'
semanage fcontext -a -t usr_t '/nix/var/nix/profiles(/.*)?'
semanage fcontext -a -t usr_t '/var/nix/var/nix/profiles(/.*)?'

systemctl enable nix.mount nix-daemon.socket

# Do not carry package-manager runtime state into the bootable image.
dnf5 clean all
rm -rf /run/dnf /var/lib/dnf/repos
