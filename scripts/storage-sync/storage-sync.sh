#!/usr/bin/env bash

MOUNT=$1

case $MOUNT in
  media) PORT=5572 ;;
  immich) PORT=5573 ;;
  private) PORT=5574 ;;
  shared) PORT=5575 ;;
  *) 
    echo "Error: Only valid mounts (media, immich, private, shared) are synced across the fleet."
    echo "Usage: storage-sync shared | storage-sync private"
    exit 1 
    ;;
esac

NODES=(
  "homelab-one"
  "devil"
  "daredevil"
  "old-devil"
  "oneplus-13"
)

CURRENT_HOST=$(hostname)

echo "Broadcasting VFS refresh for '$MOUNT' to Tailscale fleet on port $PORT..."

for NODE in "${NODES[@]}"; do
  if [ "$NODE" == "$CURRENT_HOST" ]; then
    echo -n "-> Pinging $NODE (Localhost bypass)... "
    TARGET="127.0.0.1"
  else
    echo -n "-> Pinging $NODE (Tailscale)... "
    TARGET="$NODE"
  fi

  if curl -s --max-time 2 -X POST "http://$TARGET:$PORT/vfs/refresh" -d '{"recursive":true}' > /dev/null; then
    echo "[OK]"
  else
    echo "[OFFLINE or UNREACHABLE]"
  fi
done
