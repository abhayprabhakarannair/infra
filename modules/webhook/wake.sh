#!/usr/bin/env bash
TARGET=$1

case "$TARGET" in
  "devil")
    SECRET_PATH="@devilMacPath@"
    ;;
  "daredevil")
    SECRET_PATH="@daredevilMacPath@"
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 1
    ;;
esac

MAC_ADDRESS=$(cat "$SECRET_PATH")
wakeonlan "$MAC_ADDRESS"
