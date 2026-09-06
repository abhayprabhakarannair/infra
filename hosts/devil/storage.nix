{
  lib,
  pkgs,
  inputs,
  config,
  ...
}: let
  serviceBackups = [
    {
      name = "jellyfin";
      path = "/srv/jellyfin";
      kind = "sqlite";
    }
    {
      name = "prowlarr";
      path = "/srv/prowlarr";
      kind = "tree";
    }
    {
      name = "sonarr";
      path = "/srv/sonarr";
      kind = "sqlite";
    }
    {
      name = "radarr";
      path = "/srv/radarr";
      kind = "sqlite";
    }
    {
      name = "sabnzbd";
      path = "/srv/sabnzbd";
      kind = "tree";
    }
    {
      name = "downloads";
      path = "/srv/downloads";
      kind = "tree";
    }
    {
      name = "whisparr";
      path = "/srv/whisparr";
      kind = "sqlite";
    }
    {
      name = "gluetun";
      path = "/srv/gluetun";
      kind = "tree";
    }
    {
      name = "qbittorrent";
      path = "/srv/qbittorrent";
      kind = "tree";
    }
    {
      name = "seerr";
      path = "/srv/seerr";
      kind = "sqlite";
    }
    {
      name = "stash";
      path = "/srv/stash";
      kind = "sqlite";
    }
  ];
  serviceDirectories = map (entry: entry.path) serviceBackups ++ ["/srv/immich/postgres"];
  backupSources = serviceDirectories ++ ["/var/lib/libvirt"];
  backupSourceList = lib.concatStringsSep " " (map lib.escapeShellArg backupSources);
  backupOperations =
    lib.concatMapStringsSep "\n" (
      entry:
        if entry.kind == "sqlite"
        then "          infra_backup_sqlite_service ${entry.path} \"$STAGING\" ${entry.name} \"$DEST/${entry.name}\" \"$CONFIG\""
        else "          infra_backup_tree ${entry.path} \"$DEST/${entry.name}\" \"$CONFIG\""
    )
    serviceBackups;
in {
  imports = [
    "${inputs.self}/modules/storage/main.nix"
    "${inputs.self}/modules/syncthing"
  ];

  systemd.tmpfiles.rules = ["d /mnt/homelab 0750 1000 1000 -"];

  myStorage.persistBackup.extraExcludedPaths = ["var/lib/ollama/**"];
  myImpermanence.serviceDirectories = serviceDirectories;

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
    path = with pkgs; [coreutils findutils gnugrep rclone sqlite util-linux];
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

                    for source in ${backupSourceList}; do
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

          ${backupOperations}
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
