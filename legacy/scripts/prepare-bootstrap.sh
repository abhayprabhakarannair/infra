#!/usr/bin/env bash
set -euo pipefail

umask 077

usage() {
    echo "Usage: ./prepare-bootstrap.sh <host-target>"
    echo "Example: ./prepare-bootstrap.sh daredevil"
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

TARGET=$1
case "$TARGET" in
    daredevil|devil|old-devil|homelab-one) ;;
    *)
        echo "Error: unsupported host '$TARGET'."
        echo "Expected one of: daredevil, devil, old-devil, homelab-one."
        exit 1
        ;;
esac

BOOTSTRAP_ROOT="${HOME:?}/.server-bootstrap"
TARGET_ROOT="$BOOTSTRAP_ROOT/$TARGET"
KEY_DIR="$TARGET_ROOT/etc/ssh"
PRIVATE_KEY="$KEY_DIR/ssh_host_ed25519_key"
PUBLIC_KEY="${PRIVATE_KEY}.pub"

for path in "$BOOTSTRAP_ROOT" "$TARGET_ROOT" "$KEY_DIR" "$PRIVATE_KEY" "$PUBLIC_KEY"; do
    if [ -L "$path" ]; then
        echo "Error: refusing to follow symlink '$path'."
        exit 1
    fi
done

mkdir -p "$KEY_DIR"
chmod 700 "$BOOTSTRAP_ROOT" "$TARGET_ROOT" "$KEY_DIR"

if [ -e "$PRIVATE_KEY" ] || [ -e "$PUBLIC_KEY" ]; then
    if [ ! -f "$PRIVATE_KEY" ] || [ ! -f "$PUBLIC_KEY" ]; then
        echo "Error: incomplete bootstrap key pair in '$KEY_DIR'."
        exit 1
    fi
    if [ "$(stat -c '%a' "$PRIVATE_KEY")" != "600" ]; then
        echo "Error: private key '$PRIVATE_KEY' must have mode 600."
        exit 1
    fi
    if [ "$(stat -c '%a' "$PUBLIC_KEY")" != "644" ]; then
        echo "Error: public key '$PUBLIC_KEY' must have mode 644."
        exit 1
    fi
    echo "Bootstrap files already exist for $TARGET at $KEY_DIR."
    exit 0
fi

echo "Creating bootstrap directory structure for $TARGET..."

install -m 600 /dev/null "$PRIVATE_KEY"
install -m 644 /dev/null "$PUBLIC_KEY"

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
