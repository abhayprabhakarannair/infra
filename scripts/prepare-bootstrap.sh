#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./prepare-bootstrap.sh <host-target>"
    echo "Example: ./prepare-bootstrap.sh daredevil"
    exit 1
fi

TARGET=$1
KEY_DIR="$HOME/.server-bootstrap/$TARGET/etc/ssh"
PRIVATE_KEY="$KEY_DIR/ssh_host_ed25519_key"
PUBLIC_KEY="${PRIVATE_KEY}.pub"

# Check if we already scaffolded this host
if [ -f "$PRIVATE_KEY" ]; then
    echo "⚠️  Bootstrap files already exist for $TARGET at $KEY_DIR!"
    exit 0
fi

echo "Creating bootstrap directory structure for $TARGET..."

# 1. Create the exact folder structure
mkdir -p "$KEY_DIR"

# 2. Create the empty files
touch "$PRIVATE_KEY"
touch "$PUBLIC_KEY"

# 3. Lock down the permissions immediately (SSH strictly requires 600 for private keys)
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

echo "✅ Folder structure created successfully."
echo ""
echo "========================================================"
echo " 🛑 ACTION REQUIRED: PASTE YOUR KEYS FROM BITWARDEN 🛑"
echo "========================================================"
echo "1. Open your private key in nano:"
echo "   nano $PRIVATE_KEY"
echo ""
echo "2. Open your public key in nano:"
echo "   nano $PUBLIC_KEY"
echo ""
echo "Once you have saved both files, run this command to get the AGE key for your .sops.yaml:"
echo "cat $PUBLIC_KEY | nix-shell -p ssh-to-age --run ssh-to-age"
echo "========================================================"
