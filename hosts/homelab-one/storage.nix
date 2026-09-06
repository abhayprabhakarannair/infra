{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  serviceBackups = [
    {
      name = "vaultwarden";
      path = "/srv/vaultwarden";
      kind = "sqlite";
    }
    {
      name = "caddy";
      path = "/var/lib/caddy";
      kind = "tree";
    }
  ];
  serviceDirectories = ["/srv/vaultwarden"];
  backupSources = map (entry: entry.path) serviceBackups;
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
    "${inputs.self}/modules/storage/backup-node.nix"
  ];

  myImpermanence.serviceDirectories = serviceDirectories;

  systemd.timers.backup-homelab-storage-one = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
    };
  };

  systemd.services.backup-homelab-storage-one = {
    description = "Backup homelab-one service state and mirror StorageBox to B2";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = with pkgs; [coreutils findutils gnugrep rclone sqlite util-linux];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "backup-homelab-storage-one";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [
        "/srv"
        "/var/lib/caddy"
      ];
      TimeoutStartSec = "12h";
      ExecStart = let
        script = pkgs.writeShellScript "backup-homelab-srv" ''
                    set -euo pipefail
                    source /etc/infra/backup-lib.sh

                    RUNTIME_DIR=/run/backup-homelab-storage-one
                    STAMP=$(date -u +%Y%m%dT%H%M%SZ)
                    CONFIG=${config.sops.secrets."rclone-backup-node.conf".path}
                    DEST="b2-storage:/disaster-recovery/homelab-one/services/$STAMP"
                    STAGING="$RUNTIME_DIR/sqlite"

                    cleanup() {
                      ${pkgs.coreutils}/bin/rm -rf -- "$STAGING"
                    }
                    trap cleanup EXIT

                    exec 9>"$RUNTIME_DIR/backup.lock"
                    if ! ${pkgs.util-linux}/bin/flock -n 9; then
                      echo "backup-homelab-storage-one is already running" >&2
                      exit 0
                    fi

                    for source in ${backupSourceList}; do
                    infra_require_dir "$source" || {
                      echo "required backup source is missing: $source" >&2
                        exit 1
                      }
                    done
                    ${pkgs.coreutils}/bin/mkdir -p "$STAGING"

          ${backupOperations}

                    infra_prune_generations "b2-storage:/disaster-recovery/homelab-one/services" "$CONFIG" 90 "$RUNTIME_DIR/service-generations.list"

                    SOURCE_LIST="$RUNTIME_DIR/source.list"
                    ${pkgs.rclone}/bin/rclone lsf homelab-storage-one:/ --recursive \
                      --config="$CONFIG" --log-level ERROR --stats 0 > "$SOURCE_LIST"
                    test -s "$SOURCE_LIST" || {
                      echo "homelab-storage-one source is empty; refusing replica sync" >&2
                      exit 1
                    }
                    ${pkgs.rclone}/bin/rclone sync homelab-storage-one:/ b2-storage:homelab-storage-one-replica/ \
                      --config="$CONFIG" \
                      --backup-dir="b2-storage:homelab-storage-one-replica-history/$STAMP" \
                      --fast-list --transfers 4 --checkers 8 --contimeout 1m --low-level-retries 10 \
                      --retries 3 --retries-sleep 30s --log-level ERROR --stats 0
                    infra_prune_generations "b2-storage:homelab-storage-one-replica-history" "$CONFIG" 90 "$RUNTIME_DIR/replica-generations.list"
        '';
      in "${script}";
    };
  };
}
