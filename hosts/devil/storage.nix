{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/main.nix"
    "${inputs.self}/modules/syncthing"
  ];

  systemd.tmpfiles.rules = ["d /mnt/homelab 0750 1000 1000 -"];

  # Ollama models are deliberately reconstructible: they are large, can be
  # re-pulled from their declared source, and are not a recovery dependency.
  # The /persist backup module excludes this tree while service metadata and
  # all other declared durable state remain covered.
  myStorage.persistBackup.extraExcludedPaths = ["var/lib/ollama/**"];

  systemd.services = {
    rclone-homelab = {
      description = "Rclone mount for Encrypted Homelab Storage One";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/homelab || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/homelab
      '';

      serviceConfig = {
        Type = "notify";
        TimeoutStartSec = "600";
        # Keep the reconstructible VFS cache out of /tmp and let systemd
        # create it with a known owner/mode. The cache is still on the root
        # filesystem, so the rclone limits below remain important.
        CacheDirectory = "rclone-homelab";
        CacheDirectoryMode = "0700";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/homelab; do sleep 1; done'";
        ExecStart = ''
               ${pkgs.rclone}/bin/rclone mount homelab-storage-one-combined:/ /mnt/homelab \
                 --config=${config.sops.secrets."rclone-main.conf".path} \
                 --cache-dir=/var/cache/rclone-homelab \
                 --vfs-cache-mode=full \
                 --vfs-cache-max-size=32G \
                 --vfs-cache-min-free-space=20G \
                 --vfs-cache-max-age=72h \
                 --vfs-write-back=5s \
                 --vfs-read-chunk-size=64M \
                 --vfs-read-chunk-size-limit=2G \
                 --vfs-read-ahead=128M \
                 --buffer-size=32M \
                 --allow-other \
                 --log-level=INFO \
                 --timeout=10m \
                 --contimeout=60s \
                 --transfers=4 \
          --sftp-chunk-size=255k \
          --sftp-idle-timeout=5m \
          --dir-cache-time=1000h \
          --checkers=4
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/homelab";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/homelab";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };

  systemd.services.backup-devil-srv = {
    description = "Backup devil service state to StorageBox";
    wants = ["network-online.target"];
    after = ["network-online.target" "podman-immich-database.service"];
    requires = ["podman-immich-database.service"];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "backup-devil-srv";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [
        "/srv"
        "/var/lib/libvirt"
      ];
      TimeoutStartSec = "12h";
      ExecStart = let
        script = pkgs.writeShellScript "backup-devil-srv" ''
          set -euo pipefail

          source /etc/infra/backup-lib.sh

          readonly RCLONE=${pkgs.rclone}/bin/rclone
          readonly SQLITE=${pkgs.sqlite}/bin/sqlite3
          readonly CONFIG=${config.sops.secrets."rclone-main.conf".path}
          RUNTIME_DIR=/run/backup-devil-srv
          STAMP=$(date -u +%Y%m%dT%H%M%SZ)
          DEST="backups:/disaster-recovery/devil/services/$STAMP"
          STAGING="$RUNTIME_DIR/sqlite"

          cleanup() {
            ${pkgs.coreutils}/bin/rm -rf -- "$STAGING"
          }
          trap cleanup EXIT

          # systemd normally serializes a oneshot service, but the lock also
          # protects against manual starts and overlapping timer invocations.
          exec 9>"$RUNTIME_DIR/backup.lock"
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            echo "backup-devil-srv is already running" >&2
            exit 0
          fi

          # These are the durable service paths declared by devil. A missing
          # source is a failed backup, never an empty replacement. Empty
          # directories are valid for a newly-installed or unused service.
          for source in \
            /srv/jellyfin \
            /srv/immich/postgres \
            /srv/prowlarr \
            /srv/sonarr \
            /srv/radarr \
            /srv/sabnzbd \
            /srv/downloads \
            /srv/whisparr \
            /srv/gluetun \
            /srv/qbittorrent \
            /srv/seerr \
            /srv/stash \
            /var/lib/libvirt; do
            infra_require_dir "$source" || {
              echo "required backup source is missing: $source" >&2
              exit 1
            }
          done

          ${pkgs.coreutils}/bin/mkdir -p "$STAGING"

          # Database files are excluded from tree copies and exported with
          # SQLite's online backup API. This covers the SQLite-backed Arr,
          # Jellyfin, Stash, and Seerr state without copying live DB files.
          backup_sqlite_service() {
            local source="$1"
            local destination="$2"
            infra_rclone_copy_checked "$source" "$DEST/$destination" "$CONFIG" \
              --fast-list --transfers 4 --checkers 8 \
              --exclude '**/*.db' --exclude '**/*.db-*' \
              --exclude '**/*.sqlite' --exclude '**/*.sqlite-*' \
              --exclude '**/*.sqlite3'
            infra_export_sqlite_tree "$source" "$STAGING" "$destination" "$DEST/$destination" "$CONFIG"
          }

          backup_plain_service() {
            local source="$1"
            local destination="$2"
            infra_rclone_copy_checked "$source" "$DEST/$destination" "$CONFIG" \
              --fast-list --transfers 4 --checkers 8
          }

          # Immich DB — clean dump via pg_dump (consistent snapshot, safe during writes)
          # Restore:
          #   gunzip -c immich-db.sql.gz | podman exec -i immich-database psql -U postgres immich
          DUMP="$RUNTIME_DIR/immich-db.sql.gz"
          ${pkgs.podman}/bin/podman exec immich-database pg_dump -U postgres immich \
            | ${pkgs.gzip}/bin/gzip > "$DUMP"
          test -s "$DUMP"
          ${pkgs.gzip}/bin/gzip -t "$DUMP"
          infra_rclone_copy_checked "$DUMP" "$DEST/immich/postgres" "$CONFIG"

          backup_sqlite_service /srv/jellyfin jellyfin
          backup_plain_service /srv/prowlarr prowlarr
          backup_sqlite_service /srv/sonarr sonarr
          backup_sqlite_service /srv/radarr radarr
          backup_plain_service /srv/sabnzbd sabnzbd
          backup_plain_service /srv/downloads downloads
          backup_sqlite_service /srv/whisparr whisparr
          backup_plain_service /srv/gluetun gluetun
          backup_plain_service /srv/qbittorrent qbittorrent
          backup_sqlite_service /srv/seerr seerr
          backup_sqlite_service /srv/stash stash
          backup_plain_service /var/lib/libvirt libvirt

          # Keep 90 days of complete service generations. Retention is based
          # on generation directory names and is intentionally separate from
          # the /persist recovery generations.
          infra_prune_generations "backups:/disaster-recovery/devil/services" "$CONFIG" 90 "$RUNTIME_DIR/generations.list"
        '';
      in "${script}";
    };
  };

  systemd.timers.backup-devil-srv = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
