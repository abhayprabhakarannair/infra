#!/usr/bin/env bash
set -euo pipefail

bootstrap_dir="${HOME:?}/.server-bootstrap/daredevil/persistent/etc/ssh"
private_key="$bootstrap_dir/ssh_host_ed25519_key"
public_key="$private_key.pub"

if [ -e "$private_key" ] || [ -e "$public_key" ]; then
  echo "Bootstrap key files already exist at $bootstrap_dir." >&2
  exit 1
fi

mkdir -p "$bootstrap_dir"
chmod 700 "${HOME:?}/.server-bootstrap" "${HOME:?}/.server-bootstrap/daredevil" "$bootstrap_dir"
install -m 600 /dev/null "$private_key"
install -m 644 /dev/null "$public_key"

cat >&2 <<EOF
Restore the existing daredevil SSH host-key pair into:

  $private_key
  $public_key

The private key must be mode 600 and the public key mode 644.
EOF
