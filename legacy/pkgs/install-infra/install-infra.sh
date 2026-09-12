#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: install-infra <host-target> <ip-address> [ssh-port]"
    echo "Example: install-infra homelab-one 192.168.1.50"
    echo "Example (custom port): install-infra homelab-one 192.168.1.50 2442"
    exit 1
fi

TARGET=$1
IP=$2
case "$TARGET" in
    daredevil|devil|old-devil|homelab-one) ;;
    *)
        echo "Error: unsupported host '$TARGET'."
        echo "Expected one of: daredevil, devil, old-devil, homelab-one."
        exit 1
        ;;
esac

PORT=${3:-22}
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: SSH port must be an integer between 1 and 65535."
    exit 1
fi

BOOTSTRAP_DIR="${HOME:?}/.server-bootstrap/$TARGET"
PRIVATE_KEY="$BOOTSTRAP_DIR/etc/ssh/ssh_host_ed25519_key"
PUBLIC_KEY="${PRIVATE_KEY}.pub"

# Fail if the bootstrap directory is not present
if [ ! -d "$BOOTSTRAP_DIR" ]; then
    echo "❌ Error: Bootstrap folder missing!"
    echo "Expected it here: $BOOTSTRAP_DIR"
    echo "Please generate the host keys for $TARGET first (script -> prepare-bootstrap.sh)."
    exit 1
fi

if [ -L "$BOOTSTRAP_DIR" ] || [ -L "$PRIVATE_KEY" ] || [ -L "$PUBLIC_KEY" ]; then
    echo "Error: bootstrap path contains a symlink; refusing to deploy."
    exit 1
fi

if [ ! -s "$PRIVATE_KEY" ] || [ ! -s "$PUBLIC_KEY" ]; then
    echo "Error: bootstrap SSH key pair is missing or empty."
    echo "Populate '$PRIVATE_KEY' and '$PUBLIC_KEY' before deploying."
    exit 1
fi

if [ "$(stat -c '%a' "$PRIVATE_KEY")" != "600" ] || [ "$(stat -c '%a' "$PUBLIC_KEY")" != "644" ]; then
    echo "Error: bootstrap key permissions must be 600 (private) and 644 (public)."
    exit 1
fi

echo "Deploying $TARGET to $IP on SSH port $PORT..."

nixos-anywhere \
    --ssh-port "$PORT" \
    --flake ".#${TARGET}" \
    --generate-hardware-config nixos-generate-config "./hosts/$TARGET/hardware.nix" \
    --extra-files "$BOOTSTRAP_DIR" \
    "root@$IP"
