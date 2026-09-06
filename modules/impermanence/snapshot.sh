#!/usr/bin/env bash
set -euo pipefail

if ! mountpoint --quiet /persist; then
  echo "impermanence-snapshot: /persist is not mounted" >&2
  exit 1
fi

stamp=$(date -u +%Y%m%d-%H%M%S)
destination="/persist/rollback/$stamp"
mkdir -p "$destination"

btrfs subvolume snapshot -r / "$destination/root"
btrfs subvolume snapshot -r /home "$destination/home"

echo "Created read-only rollback snapshots under $destination"
