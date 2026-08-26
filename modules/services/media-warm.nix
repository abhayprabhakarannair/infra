{
  config,
  pkgs,
  inputs,
  ...
}: {
  sops.secrets."jellyfin/api-key" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
    owner = "root";
    mode = "0400";
  };

  # Pre-warm the rclone VFS cache with what Abhay is likely to watch next,
  # so Jellyfin/Stash playback is served from local disk instead of stalling
  # on SFTP fetch from the Hetzner box (the source of buffering).
  systemd.services.media-warm = {
    description = "Pre-warm rclone VFS cache with next-up media";
    after = [
      "network-online.target"
      "rclone-homelab.service"
      "podman-jellyfin.service"
    ];
    wants = ["network-online.target"];
    requires = ["rclone-homelab.service"];

    path = with pkgs; [
      curl
      jq
      coreutils
      gnused
      util-linux
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      StateDirectory = "media-warm";
      Environment = [
        "JF_BASE=http://localhost:8096"
        "MAX_BYTES_PER_RUN=25000000000"
      ];
      ExecStart = let
        script = pkgs.writeShellScript "media-warm" ''
          set -euo pipefail

          KEY=$(cat ${config.sops.secrets."jellyfin/api-key".path})
          ST=/var/lib/media-warm/state.json
          : > /tmp/media-warm-candidates.txt
          : > /tmp/media-warm-done.txt

          # Resolve first user id
          UID_=$(curl -sf -H "X-Emby-Token: $KEY" \
            "$JF_BASE/Users" | jq -r '.[0].Id // empty' || true)
          [ -n "$UID_" ] || { echo "no jellyfin user"; exit 0; }

          # Gather candidate paths (Resume + NextUp + RecentlyAdded)
          curl -sf -H "X-Emby-Token: $KEY" \
            "$JF_BASE/Users/$UID_/Items/Resume?Fields=Path&Limit=8" \
            | jq -r '.Items[]?.Path // empty' >> /tmp/media-warm-candidates.txt 2>/dev/null || true
          curl -sf -H "X-Emby-Token: $KEY" \
            "$JF_BASE/Shows/NextUp?UserId=$UID_&Fields=Path&Limit=6" \
            | jq -r '.Items[]?.Path // empty' >> /tmp/media-warm-candidates.txt 2>/dev/null || true
          curl -sf -H "X-Emby-Token: $KEY" \
            "$JF_BASE/Users/$UID_/Items/Latest?Fields=Path&Limit=5" \
            | jq -r '.[].Path // empty' >> /tmp/media-warm-candidates.txt 2>/dev/null || true

          # Normalise container paths back to host paths
          sed -i \
            -e 's#^/media/#/mnt/homelab/media/#' \
            -e 's#^/music/#/mnt/homelab/media/music/#' \
            /tmp/media-warm-candidates.txt

          sort -u /tmp/media-warm-candidates.txt -o /tmp/media-warm-candidates.txt

          # Reject anything already warmed recently (state = size:mtime)
          [ -f "$ST" ] || echo '{}' > "$ST"
          now=$(date +%s)
          warmed=0
          bytes=0
          while IFS= read -r p; do
            [ -n "$p" ] || continue
            [ -f "$p" ] || continue
            size=$(stat -c %s "$p" 2>/dev/null || echo 0)
            mtime=$(stat -c %Y "$p" 2>/dev/null || echo 0)
            last=$(jq -r --arg p "$p" '.[$p].warmedAt // 0' "$ST")
            # skip if warmed within the last 24h AND size+mtime unchanged
            if [ "$((now - last))" -lt 86400 ] && \
               [ "$(jq -r --arg p "$p" '.[$p].size // 0' "$ST")" = "$size" ] && \
               [ "$(jq -r --arg p "$p" '.[$p].mtime // 0' "$ST")" = "$mtime" ]; then
              continue
            fi
            # cap total bytes per run
            if [ "$((bytes + size))" -gt "$MAX_BYTES_PER_RUN" ]; then
              echo "run cap reached at $p" >&2
              break
            fi
            echo "warming: $p ($size bytes)"
            # force a full read through the VFS mount -> populates rclone cache
            dd if="$p" of=/dev/null bs=4M 2>/dev/null || true
            bytes=$((bytes + size))
            warmed=$((warmed + 1))
            jq --arg p "$p" --argjson s "$size" --argjson m "$mtime" --argjson t "$now" \
              '.[$p] = {size: $s, mtime: $m, warmedAt: $t}' "$ST" > "$ST.tmp"
            mv "$ST.tmp" "$ST"
          done < /tmp/media-warm-candidates.txt

          echo "media-warm done: $warmed files warmed ($bytes bytes)"
        '';
      in "${script}";
    };
  };

  systemd.timers.media-warm = {
    description = "Every 2h media cache pre-warm";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* *:0/2";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
  };
}
