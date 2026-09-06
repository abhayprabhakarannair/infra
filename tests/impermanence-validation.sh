#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cache_root="${XDG_CACHE_HOME:-/tmp}/infra-nix-cache"
mkdir -p "$cache_root"

for host in daredevil devil old-devil homelab-one; do
  echo "validating $host"
  system=$(XDG_CACHE_HOME="$cache_root" nix build \
    --no-link \
    --no-update-lock-file \
    --print-out-paths \
    "path:$repo_root#nixosConfigurations.$host.config.system.build.toplevel")

  mount_count=0
  while IFS= read -r unit_link; do
    unit=$(readlink -f "$unit_link")
    if ! grep -q '^What=/persist/' "$unit"; then
      continue
    fi
    mount_count=$((mount_count + 1))
    grep -qx 'After=persist.mount' "$unit"
    grep -qx 'Requires=persist.mount' "$unit"
  done < <(find -L "$system/etc/systemd/system" -maxdepth 1 -type f -name '*.mount' -print)

  test "$mount_count" -gt 0

  service_count=0
  while IFS= read -r unit_link; do
    unit=$(readlink -f "$unit_link")
    if ! grep -q '^Description=.* /persist/' "$unit"; then
      continue
    fi
    service_count=$((service_count + 1))
    grep -qx 'After=persist.mount' "$unit"
    grep -qx 'Requires=persist.mount' "$unit"
  done < <(find -L "$system/etc/systemd/system" -maxdepth 1 -type f -name 'persist-*.service' -print)

  test "$service_count" -gt 0
done

grep -q 'migration_marker=/persist/.impermanence-state-seeded-v3' \
  "$repo_root/modules/impermanence/prepare-reset.sh"
grep -q 'impermanence-state-seeded-v3' \
  "$repo_root/modules/impermanence/reset-initrd.sh"
grep -q '/dev/disk/by-label/NixOS' "$repo_root/hosts"/*/default.nix

if grep -q -- "-name '\*.db-\*'\|-name '\*.sqlite-\*'" \
  "$repo_root/modules/storage/backup-lib.sh"; then
  echo "SQLite sidecar patterns must not be used for sqlite3 export discovery" >&2
  exit 1
fi
grep -q '????????T??????Z)' "$repo_root/modules/storage/backup-lib.sh"
grep -q '????????T??????Z)' "$repo_root/modules/storage/persist-backup.nix"
grep -q 'environment.etc."infra/backup-lib.sh".source = ./backup-lib.sh' \
  "$repo_root/modules/storage/core.nix"

echo "impermanence validation passed"
