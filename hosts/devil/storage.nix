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

          exec 9>"$RUNTIME_DIR/backup.lock"
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            echo "backup-devil-srv is already running" >&2
            exit 0
          fi

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

          DUMP="$RUNTIME_DIR/immich-db.sql.gz"
          ${pkgs.podman}/bin/podman exec immich-database pg_dump -U postgres immich \
            | ${pkgs.gzip}/bin/gzip > "$DUMP"
          test -s "$DUMP"
          ${pkgs.gzip}/bin/gzip -t "$DUMP"
          infra_rclone_copy_checked "$DUMP" "$DEST/immich/postgres" "$CONFIG"

          infra_backup_sqlite_service /srv/jellyfin "$STAGING" jellyfin "$DEST/jellyfin" "$CONFIG"
          infra_backup_tree /srv/prowlarr "$DEST/prowlarr" "$CONFIG"
          infra_backup_sqlite_service /srv/sonarr "$STAGING" sonarr "$DEST/sonarr" "$CONFIG"
          infra_backup_sqlite_service /srv/radarr "$STAGING" radarr "$DEST/radarr" "$CONFIG"
          infra_backup_tree /srv/sabnzbd "$DEST/sabnzbd" "$CONFIG"
          infra_backup_tree /srv/downloads "$DEST/downloads" "$CONFIG"
          infra_backup_sqlite_service /srv/whisparr "$STAGING" whisparr "$DEST/whisparr" "$CONFIG"
          infra_backup_tree /srv/gluetun "$DEST/gluetun" "$CONFIG"
          infra_backup_tree /srv/qbittorrent "$DEST/qbittorrent" "$CONFIG"
          infra_backup_sqlite_service /srv/seerr "$STAGING" seerr "$DEST/seerr" "$CONFIG"
          infra_backup_sqlite_service /srv/stash "$STAGING" stash "$DEST/stash" "$CONFIG"
          infra_backup_tree /var/lib/libvirt "$DEST/libvirt" "$CONFIG"

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
