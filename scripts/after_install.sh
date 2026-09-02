#!/usr/bin/env bash

# This script is expected to run after first reboot to the system

set -euo pipefail

# Secret-bearing files must never inherit a permissive caller umask.
umask 077

SOPS_AGE_DIR="${HOME}/.config/sops/age"
SOPS_AGE_KEY_FILE="${SOPS_AGE_DIR}/keys.txt"
TEMP_SOPS_AGE_KEY=""

cleanup() {
    if [ -n "${TEMP_SOPS_AGE_KEY}" ] && [ -e "${TEMP_SOPS_AGE_KEY}" ]; then
        rm -f -- "${TEMP_SOPS_AGE_KEY}"
    fi
}

trap cleanup EXIT

# Check if both arguments are provided
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: ./after_install.sh <hostname> <luks_partition> [--replace-sops-key]"
    echo "Example: ./after_install.sh daredevil /dev/nvme0n1p2"
    echo "Example: ./after_install.sh devil /dev/nvme1n1p2"
    exit 1
fi

HOSTNAME="$1"
LUKS_PARTITION="$2"
REPLACE_SOPS_KEY=false

if [ "$#" -eq 3 ]; then
    if [ "$3" != "--replace-sops-key" ]; then
        echo "Error: Unknown option '$3'."
        exit 1
    fi
    REPLACE_SOPS_KEY=true
fi

# Safety check: Verify the block device actually exists
if [ ! -b "$LUKS_PARTITION" ]; then
    echo "Error: Partition '$LUKS_PARTITION' does not exist on this system."
    exit 1
fi

echo "Enrolling TPM2 for $HOSTNAME on partition $LUKS_PARTITION..."
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 "$LUKS_PARTITION"
echo "TPM2 enrollment complete."

echo "Adding SOPS Decryption Setup..."
mkdir -p -- "${SOPS_AGE_DIR}"
chmod 700 -- "${SOPS_AGE_DIR}"

if [ -e "${SOPS_AGE_KEY_FILE}" ] || [ -L "${SOPS_AGE_KEY_FILE}" ]; then
    if [ "${REPLACE_SOPS_KEY}" != true ]; then
        echo "Error: '${SOPS_AGE_KEY_FILE}' already exists; refusing to overwrite it."
        echo "Use --replace-sops-key only after confirming the old identity is no longer needed."
        exit 1
    fi
    if [ -d "${SOPS_AGE_KEY_FILE}" ]; then
        echo "Error: '${SOPS_AGE_KEY_FILE}' is a directory."
        exit 1
    fi
fi

# Keep the temporary identity in the private destination directory. mktemp
# creates it before ssh-to-age writes, avoiding predictable paths and races.
TEMP_SOPS_AGE_KEY=$(mktemp "${SOPS_AGE_DIR}/.keys.txt.XXXXXX")
chmod 600 -- "${TEMP_SOPS_AGE_KEY}"
sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > "${TEMP_SOPS_AGE_KEY}"

if command -v age-keygen >/dev/null 2>&1; then
    if ! age-keygen -y "${TEMP_SOPS_AGE_KEY}" >/dev/null; then
        echo "Error: ssh-to-age did not produce a valid age identity."
        exit 1
    fi
elif ! grep --quiet -- '^AGE-SECRET-KEY-' "${TEMP_SOPS_AGE_KEY}"; then
    echo "Error: ssh-to-age did not produce an age identity."
    exit 1
fi

if [ "${REPLACE_SOPS_KEY}" = true ]; then
    mv -f -- "${TEMP_SOPS_AGE_KEY}" "${SOPS_AGE_KEY_FILE}"
else
    # A hard link gives a no-overwrite install: if the destination appeared
    # after the check above, the operation fails instead of replacing it.
    ln -- "${TEMP_SOPS_AGE_KEY}" "${SOPS_AGE_KEY_FILE}"
    rm -f -- "${TEMP_SOPS_AGE_KEY}"
fi
chmod 600 -- "${SOPS_AGE_KEY_FILE}"
TEMP_SOPS_AGE_KEY=""
echo "SOPS Setup completed."
