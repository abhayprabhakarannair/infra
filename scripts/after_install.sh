#!/usr/bin/env bash

# This script is expected to run after first reboot to the system

set -euo pipefail

# Check if both arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: ./after_install.sh <hostname> <luks_partition>"
    echo "Example: ./after_install.sh daredevil /dev/nvme0n1p2"
    echo "Example: ./after_install.sh devil /dev/nvme1n1p2"
    exit 1
fi

HOSTNAME="$1"
LUKS_PARTITION="$2"

# Safety check: Verify the block device actually exists
if [ ! -b "$LUKS_PARTITION" ]; then
    echo "Error: Partition '$LUKS_PARTITION' does not exist on this system."
    exit 1
fi

echo "Enrolling TPM2 for $HOSTNAME on partition $LUKS_PARTITION..."
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 "$LUKS_PARTITION"
echo "TPM2 enrollment complete."
