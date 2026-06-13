#!/usr/bin/env bash

# This script is created to help ssh copy id for fresh devices.

set -euo pipefail

# Check if both arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: ./copy-ssh-id.sh <username> <ip_address>"
    echo "Example: ./copy-ssh-id.sh root 192.168.0.6"
    exit 1
fi

USERNAME="$1"
IP_ADDRESS="$2"

echo "Copying ssh id for $USERNAME on $IP_ADDRESS..."
ssh-copy-id -o PreferredAuthentications=password -o PubkeyAuthentication=no "$USERNAME@$IP_ADDRESS"
echo "Copied SSH ids."


# After this can do like below
echo "nix run .\#install-infra homelab-two 192.168.122.81"
echo "after installing, use this to update -> NIX_SSHOPTS=\"-p 2442\" nixos-rebuild boot --target-host root@192.168.122.81  --flake .#homelab-two"

echo "All the best!!!"
