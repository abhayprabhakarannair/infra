{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/main.nix"
    "${inputs.self}/modules/syncthing"
  ];

  systemd.services.sync-private-to-homelab-storage-one = {
    description = "Encrypt and Sync Local Private Folder to Homelab Storage One";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "sync-private-to-homelab-storage-one";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      TimeoutStartSec = "6h";
      ExecStart = let
        script = pkgs.writeShellScript "sync-private-to-homelab-storage-one" ''
          set -euo pipefail

          SOURCE=/home/${config.users.users."abhay".name}/Sync/Private
          STAMP=$(date -u +%Y%m%dT%H%M%SZ)
          source /etc/infra/backup-lib.sh
          exec 9>/run/sync-private-to-homelab-storage-one/lock
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            echo "sync-private-to-homelab-storage-one is already running" >&2
            exit 0
          fi

          infra_require_dir "$SOURCE" || {
            echo "$SOURCE is missing; refusing sync" >&2
            exit 1
          }

          ${pkgs.rclone}/bin/rclone sync "$SOURCE" private: \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --backup-dir="private:private-history/$STAMP" --fast-list \
            --retries 3 --retries-sleep 30s --log-level ERROR --stats 0
          infra_prune_generations private:private-history \
            ${config.sops.secrets."rclone-main.conf".path} 90 \
            /run/sync-private-to-homelab-storage-one/generations.list
        '';
      in "${script}";
    };
  };

  systemd.timers.sync-private-to-homelab-storage-one = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  systemd.services.backup-old-devil-srv = {
    description = "Backup old-devil service state to StorageBox";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "backup-old-devil-srv";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = ["/srv"];
      TimeoutStartSec = "6h";
      ExecStart = let
        script = pkgs.writeShellScript "backup-old-devil-srv" ''
          set -euo pipefail
          source /etc/infra/backup-lib.sh

          readonly CONFIG=${config.sops.secrets."rclone-main.conf".path}
          RUNTIME_DIR=/run/backup-old-devil-srv
          STAMP=$(date -u +%Y%m%dT%H%M%SZ)
          DEST="backups:/disaster-recovery/old-devil/services/$STAMP"
          STAGING="$RUNTIME_DIR/sqlite"
          OMADA_WAS_ACTIVE=0
          TECHNITIUM_WAS_ACTIVE=0

          cleanup() {
            if [ "$OMADA_WAS_ACTIVE" -eq 1 ]; then
              ${pkgs.systemd}/bin/systemctl start podman-omada-controller.service || true
            fi
            if [ "$TECHNITIUM_WAS_ACTIVE" -eq 1 ]; then
              ${pkgs.systemd}/bin/systemctl start podman-technitium.service || true
            fi
            ${pkgs.coreutils}/bin/rm -rf -- "$STAGING"
          }
          trap cleanup EXIT

          exec 9>"$RUNTIME_DIR/backup.lock"
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            echo "backup-old-devil-srv is already running" >&2
            exit 0
          fi

          for source in /srv/home-assistant /srv/omada-controller /srv/technitium; do
            infra_require_dir "$source" || {
              echo "required backup source is missing: $source" >&2
              exit 1
            }
          done
          ${pkgs.coreutils}/bin/mkdir -p "$STAGING"

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

          backup_sqlite_service /srv/home-assistant home-assistant

          # No supported export command for these containers is declared in
          # the repository. Quiesce them before copying file-backed state.
          if ${pkgs.systemd}/bin/systemctl is-active --quiet podman-omada-controller.service; then
            OMADA_WAS_ACTIVE=1
            ${pkgs.systemd}/bin/systemctl stop podman-omada-controller.service
          fi
          if ${pkgs.systemd}/bin/systemctl is-active --quiet podman-technitium.service; then
            TECHNITIUM_WAS_ACTIVE=1
            ${pkgs.systemd}/bin/systemctl stop podman-technitium.service
          fi
          infra_rclone_copy_checked /srv/omada-controller "$DEST/omada-controller" "$CONFIG" \
            --fast-list --transfers 4 --checkers 8
          infra_rclone_copy_checked /srv/technitium "$DEST/technitium" "$CONFIG" \
            --fast-list --transfers 4 --checkers 8

          infra_prune_generations "backups:/disaster-recovery/old-devil/services" "$CONFIG" 90 "$RUNTIME_DIR/generations.list"
        '';
      in "${script}";
    };
  };

  systemd.timers.backup-old-devil-srv = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
    };
  };
}
