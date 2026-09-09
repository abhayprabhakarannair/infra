#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "Usage: prepare-bootstrap.sh [daredevil|devil]" >&2
  exit 2
fi

target_name="${1:-daredevil}"
case "$target_name" in
  daredevil|devil) ;;
  *)
    echo "Error: unsupported host '$target_name'. Expected daredevil or devil." >&2
    exit 2
    ;;
esac

bootstrap_dir="${HOME:?}/.server-bootstrap/${target_name}/persistent/etc/ssh"
private_key="$bootstrap_dir/ssh_host_ed25519_key"
public_key="$private_key.pub"

if [ -e "$private_key" ] || [ -e "$public_key" ]; then
  echo "Bootstrap key files already exist at $bootstrap_dir." >&2
  exit 1
fi

mkdir -p "$bootstrap_dir"
chmod 700 "${HOME:?}/.server-bootstrap" "${HOME:?}/.server-bootstrap/${target_name}" "$bootstrap_dir"
install -m 600 /dev/null "$private_key"
install -m 644 /dev/null "$public_key"

cat >&2 <<EOF
Restore the existing ${target_name} SSH host-key pair into:

  $private_key
  $public_key

The private key must be mode 600 and the public key mode 644.
EOF
