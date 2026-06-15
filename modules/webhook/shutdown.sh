#!/usr/bin/env bash
TARGET=$1

if [[ "$TARGET" != "devil" && "$TARGET" != "daredevil" ]]; then
  echo "Unknown target: $TARGET"
  exit 1
fi

ssh -i /run/secrets/webhook-ssh-key \
    -p 2442 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 \
    "abhay@$TARGET" 'sudo /run/current-system/sw/bin/systemctl poweroff'
