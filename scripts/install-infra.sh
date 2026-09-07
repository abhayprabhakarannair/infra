#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
  echo "Usage: install-infra daredevil <target-address> --confirm-daredevil-format" >&2
  echo "   or: install-infra daredevil <target-address> <ssh-port> --confirm-daredevil-format" >&2
  exit 2
fi

target_name="$1"
target_address="$2"
bootstrap_dir="${HOME:?}/.server-bootstrap/daredevil"
if [ "$#" -eq 3 ]; then
  ssh_port=22
  confirmation="$3"
else
  ssh_port="$3"
  confirmation="$4"
fi

if [ "$target_name" != "daredevil" ]; then
  echo "Error: only the daredevil foundation is defined." >&2
  exit 2
fi

if ! [[ "$ssh_port" =~ ^[0-9]+$ ]] || [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; then
  echo "Error: SSH port must be between 1 and 65535." >&2
  exit 2
fi

if [ "$confirmation" != "--confirm-daredevil-format" ]; then
  echo "Refusing to run without explicit confirmation to format daredevil." >&2
  exit 2
fi

echo "This will format the Disko target declared for daredevil." >&2

private_key="$bootstrap_dir/persistent/etc/ssh/ssh_host_ed25519_key"
public_key="$private_key.pub"

if [ ! -s "$private_key" ] || [ ! -s "$public_key" ]; then
  echo "Error: the daredevil bootstrap SSH host-key pair is missing." >&2
  echo "Prepare $bootstrap_dir and restore the existing host keys before installing." >&2
  exit 1
fi

if [ -L "$bootstrap_dir" ] || [ -L "$private_key" ] || [ -L "$public_key" ]; then
  echo "Error: refusing symlinked bootstrap paths." >&2
  exit 1
fi

if [ "$(stat -c '%a' "$private_key")" != "600" ] || [ "$(stat -c '%a' "$public_key")" != "644" ]; then
  echo "Error: bootstrap key permissions must be 600 and 644." >&2
  exit 1
fi

echo "The install stops before reboot; reboot requires a separate explicit action." >&2

nixos-anywhere \
  --ssh-port "$ssh_port" \
  --flake ".#daredevil" \
  --extra-files "$bootstrap_dir" \
  "root@${target_address}"
