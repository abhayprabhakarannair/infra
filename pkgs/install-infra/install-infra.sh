#!/usr/bin/env bash
set -e

# Added an optional 3rd argument for the port
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: install-infra <host-target> <ip-address> [ssh-port]"
    echo "Example: install-infra homelab-one 192.168.1.50"
    echo "Example (custom port): install-infra homelab-one 192.168.1.50 2222"
    exit 1
fi

TARGET=$1
IP=$2
PORT=${3:-22} # Defaults to 22 if the 3rd argument is left blank
BOOTSTRAP_DIR="$HOME/.server-bootstrap/$TARGET"

# Fail if the bootstrap directory is not present
if [ ! -d "$BOOTSTRAP_DIR" ]; then
    echo "❌ Error: Bootstrap folder missing!"
    echo "Expected it here: $BOOTSTRAP_DIR"
    echo "Please generate the host keys for $TARGET first (script -> prepare-bootstrap.sh)."
    exit 1
fi

echo "Deploying $TARGET to $IP on SSH port $PORT..."

nixos-anywhere \
    --ssh-port "$PORT" \
    --flake ".#$TARGET" \
    --generate-hardware-config nixos-generate-config "./hosts/$TARGET/hardware.nix" \
    --extra-files "$BOOTSTRAP_DIR" \
    "root@$IP"
