#!/usr/bin/env bash

# This script is expected to run after first reboot to the system

set -euo pipefail

# Secret-bearing files must never inherit a permissive caller umask.
umask 077

SOPS_AGE_DIR="${HOME}/.config/sops/age"
SOPS_AGE_KEY_FILE="${SOPS_AGE_DIR}/keys.txt"
TEMP_SOPS_AGE_KEY=""
SOPS_KEY_READY=false

validate_age_identity() {
    local key_file="$1"

    if command -v age-keygen >/dev/null 2>&1; then
        age-keygen -y "${key_file}" >/dev/null 2>&1
    else
        grep --quiet --extended-regexp -- '^AGE-SECRET-KEY-[A-Z0-9]+$' "${key_file}"
    fi
}

cleanup() {
    if [ -n "${TEMP_SOPS_AGE_KEY}" ] && [ -e "${TEMP_SOPS_AGE_KEY}" ]; then
        rm -f -- "${TEMP_SOPS_AGE_KEY}"
    fi
}

trap cleanup EXIT

# The LUKS partition is optional for unencrypted hosts. The script always
# prepares the SOPS age identity; TPM2 enrollment only applies to LUKS hosts.
if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    echo "Usage: ./after_install.sh <hostname> [luks_partition] [--replace-sops-key]"
    echo "Example: ./after_install.sh daredevil /dev/nvme0n1p2"
    echo "Example: ./after_install.sh devil /dev/nvme1n1p2"
    echo "Example: ./after_install.sh old-devil"
    exit 1
fi

HOSTNAME="$1"
shift

case "$HOSTNAME" in
    daredevil|devil|old-devil|homelab-one) ;;
    *)
        echo "Error: unsupported host '$HOSTNAME'."
        echo "Expected one of: daredevil, devil, old-devil, homelab-one."
        exit 1
        ;;
esac

LUKS_PARTITION=""
REPLACE_SOPS_KEY=false

if [ "$#" -gt 0 ]; then
    if [ "$1" = "--replace-sops-key" ]; then
        REPLACE_SOPS_KEY=true
        shift
    else
        LUKS_PARTITION="$1"
        shift
    fi
fi

if [ "$#" -gt 0 ]; then
    if [ "$1" != "--replace-sops-key" ]; then
        echo "Error: Unknown option '$1'."
        exit 1
    fi
    REPLACE_SOPS_KEY=true
    shift
fi

if [ "$#" -ne 0 ]; then
    echo "Error: Too many arguments."
    exit 1
fi

# Safety check: Verify the block device actually exists before changing anything.
if [ -n "$LUKS_PARTITION" ] && [ ! -b "$LUKS_PARTITION" ]; then
    echo "Error: Partition '$LUKS_PARTITION' does not exist on this system."
    exit 1
fi

if [ -z "$LUKS_PARTITION" ] && [ -e /dev/mapper/enc ]; then
    echo "Error: An active LUKS mapping exists at /dev/mapper/enc."
    echo "Pass the underlying LUKS partition explicitly for TPM2 enrollment."
    exit 1
fi

SSH_HOST_KEY=/etc/ssh/ssh_host_ed25519_key
if ! sudo test -f "$SSH_HOST_KEY" || ! sudo test -r "$SSH_HOST_KEY"; then
    echo "Error: required SSH host key '$SSH_HOST_KEY' is missing or unreadable."
    exit 1
fi

SSH_TO_AGE=$(command -v ssh-to-age || true)
if [ -z "$SSH_TO_AGE" ]; then
    echo "Error: ssh-to-age is not installed or not available in PATH."
    echo "Rebuild the host configuration with the server Home Manager role first."
    exit 1
fi

echo "Adding SOPS Decryption Setup..."
if [ -L "${SOPS_AGE_DIR}" ]; then
    echo "Error: '${SOPS_AGE_DIR}' is a symlink; refusing to write secrets through it."
    exit 1
fi
mkdir -p -- "${SOPS_AGE_DIR}"
chmod 700 -- "${SOPS_AGE_DIR}"

if [ -e "${SOPS_AGE_KEY_FILE}" ] || [ -L "${SOPS_AGE_KEY_FILE}" ]; then
    if [ -L "${SOPS_AGE_KEY_FILE}" ]; then
        if [ "${REPLACE_SOPS_KEY}" != true ]; then
            echo "Error: '${SOPS_AGE_KEY_FILE}' is a symlink; refusing to use or overwrite it."
            echo "Use --replace-sops-key only after confirming the old identity is no longer needed."
            exit 1
        fi
    elif [ -d "${SOPS_AGE_KEY_FILE}" ]; then
        echo "Error: '${SOPS_AGE_KEY_FILE}' is a directory."
        exit 1
    fi

    if [ "${REPLACE_SOPS_KEY}" != true ]; then
        if ! validate_age_identity "${SOPS_AGE_KEY_FILE}"; then
            echo "Error: '${SOPS_AGE_KEY_FILE}' is not a valid age identity."
            echo "Use --replace-sops-key only after confirming the old identity is no longer needed."
            exit 1
        fi
        chmod 600 -- "${SOPS_AGE_KEY_FILE}"
        echo "Existing SOPS age identity is valid; reusing it."
        SOPS_KEY_READY=true
    fi
fi

if [ "${SOPS_KEY_READY}" != true ]; then
    # Keep the temporary identity in the private destination directory. mktemp
    # creates it before ssh-to-age writes, avoiding predictable paths and races.
    TEMP_SOPS_AGE_KEY=$(mktemp "${SOPS_AGE_DIR}/.keys.txt.XXXXXX")
    chmod 600 -- "${TEMP_SOPS_AGE_KEY}"
    sudo "$SSH_TO_AGE" -private-key -i "$SSH_HOST_KEY" > "${TEMP_SOPS_AGE_KEY}"

    if ! validate_age_identity "${TEMP_SOPS_AGE_KEY}"; then
        echo "Error: ssh-to-age did not produce a valid age identity."
        exit 1
    fi

    if [ "${REPLACE_SOPS_KEY}" = true ]; then
        mv -fT -- "${TEMP_SOPS_AGE_KEY}" "${SOPS_AGE_KEY_FILE}"
    else
        # A hard link gives a no-overwrite install: if the destination appeared
        # after the check above, the operation fails instead of replacing it.
        ln -- "${TEMP_SOPS_AGE_KEY}" "${SOPS_AGE_KEY_FILE}"
        rm -f -- "${TEMP_SOPS_AGE_KEY}"
    fi
    chmod 600 -- "${SOPS_AGE_KEY_FILE}"
    TEMP_SOPS_AGE_KEY=""
fi
echo "SOPS Setup completed."

if [ -n "$LUKS_PARTITION" ]; then
    echo "Enrolling TPM2 for $HOSTNAME on partition $LUKS_PARTITION..."
    sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 "$LUKS_PARTITION"
    echo "TPM2 enrollment complete."
else
    echo "No LUKS partition supplied; skipping TPM2 enrollment for $HOSTNAME."
fi

echo "Setup completed."
