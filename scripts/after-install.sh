#!/usr/bin/env bash
set -euo pipefail

umask 077

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

age_dir="${HOME:?}/.config/sops/age"
age_key="$age_dir/keys.txt"
ssh_host_key="/persistent/etc/ssh/ssh_host_ed25519_key"

if ! sudo test -r "$ssh_host_key"; then
  echo "Missing persistent SSH host key: $ssh_host_key" >&2
  echo "This must be restored before running the script." >&2
  exit 1
fi

if ! command -v ssh-to-age >/dev/null 2>&1; then
  echo "ssh-to-age is not installed. Run nrb and start a new shell first." >&2
  exit 1
fi

if [ -L "$age_dir" ] || [ -L "$age_key" ]; then
  echo "Refusing to write through a symlink: $age_dir or $age_key" >&2
  exit 1
fi

mkdir -p "$age_dir"
chmod 700 "$age_dir"

if [ -e "$age_key" ]; then
  if [ ! -f "$age_key" ] || ! age-keygen -y "$age_key" >/dev/null 2>&1; then
    echo "Existing SOPS identity is invalid: $age_key" >&2
    echo "Move it aside manually if replacement is intended." >&2
    exit 1
  fi
  chmod 600 "$age_key"
  echo "Existing SOPS age identity is valid; keeping it."
else
  tmp_key=$(mktemp "$age_dir/.keys.txt.XXXXXX")
  trap 'rm -f "$tmp_key"' EXIT
  chmod 600 "$tmp_key"

  sudo ssh-to-age -private-key -i "$ssh_host_key" > "$tmp_key"
  age-keygen -y "$tmp_key" >/dev/null
  mv -fT "$tmp_key" "$age_key"
  chmod 600 "$age_key"
  trap - EXIT

  echo "SOPS age identity installed at $age_key."
fi

echo "Testing repository secrets..."
sops -d "$repo_dir/secrets/system-secrets.yaml" >/dev/null
sops -d "$repo_dir/secrets/rclone/rclone-main.conf" >/dev/null
sops -d "$repo_dir/secrets/rclone/secrets.yaml" >/dev/null
sops -d "$repo_dir/secrets/service-secrets.yaml" >/dev/null
echo "SOPS decryption works."

crypt_device=$(sudo cryptsetup status cryptroot 2>/dev/null | awk '/device:/ {print $2}')
if [ -z "$crypt_device" ] || [ ! -b "$crypt_device" ]; then
  echo "Could not discover the active cryptroot device; skipping TPM enrollment." >&2
  exit 0
fi

if sudo cryptsetup luksDump "$crypt_device" 2>/dev/null | grep -q 'systemd-tpm2'; then
  echo "TPM2 unlock is already enrolled on $crypt_device."
else
  echo "Enrolling TPM2 unlock on $crypt_device..."
  sudo systemd-cryptenroll \
    --tpm2-device=auto \
    --tpm2-pcrs=0+7 \
    "$crypt_device"
  echo "TPM2 enrollment complete."
fi
