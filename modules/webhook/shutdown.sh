#!/usr/bin/env bash
TARGET=$1

if [[ "$TARGET" != "devil" && "$TARGET" != "daredevil" ]]; then
  echo "Unknown target: $TARGET"
  exit 1
fi

ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$TARGET" 'systemctl poweroff'
