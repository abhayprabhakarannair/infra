#!/usr/bin/env bash
for path in \
  /etc/machine-id \
  /etc/ssh/ssh_host_ed25519_key \
  /etc/ssh/ssh_host_ed25519_key.pub \
  /etc/ssh/ssh_host_rsa_key \
  /etc/ssh/ssh_host_rsa_key.pub \
  /var/lib/systemd/random-seed; do
  if [ -e "$path" ] && ! @findmnt@ --mountpoint "$path" >/dev/null 2>&1; then
    @rm@ -f -- "$path" 2>/dev/null || true
  fi
done
