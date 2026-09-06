{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myStorage.persistBackup;
  host = config.networking.hostName;
  serviceName = "backup-${host}-persist";
  generationRoot = "${cfg.remote}/persist";
  excludedPaths = [
    "rollback/**"
    "**/.cache/**"
    "var/cache/**"
    "srv/immich/postgres/**"
    "srv/vaultwarden/db.sqlite3"
    "srv/home-assistant/home-assistant_v2.db"
    "srv/**/*.db"
    "srv/**/*.db-*"
    "srv/*.db"
    "srv/*.db-*"
    "srv/**/*.sqlite"
    "srv/**/*.sqlite-*"
    "srv/*.sqlite"
    "srv/*.sqlite-*"
    "srv/**/*.sqlite3"
    "srv/*.sqlite3"
  ];
  excludeArgs = lib.concatMapStringsSep " " (pattern: "--exclude ${lib.escapeShellArg pattern}") (excludedPaths ++ cfg.extraExcludedPaths);
in {
  options.myStorage.persistBackup = {
    enable = lib.mkEnableOption "versioned disaster-recovery backup of /persist";

    remote = lib.mkOption {
      type = lib.types.str;
      description = "Existing rclone destination used for disaster-recovery generations.";
    };

    configPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to the already-declared rclone configuration secret.";
    };

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "How long completed disaster-recovery generations are retained.";
    };

    extraExcludedPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional reconstructible paths excluded from the persistence recovery copy.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.${serviceName} = {
      description = "Versioned disaster-recovery backup of ${host} persistence";
      wants = ["network-online.target"];
      after = ["network-online.target" "persist.mount"];
      unitConfig = {
        AssertPathIsMountPoint = "/persist";
        ConditionPathExists = "/persist/.impermanence-ready";
      };
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = serviceName;
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = ["/persist"];
        TimeoutStartSec = "12h";
        ExecStart = let
          script = pkgs.writeShellScript serviceName ''
            set -euo pipefail

            readonly RCLONE=${pkgs.rclone}/bin/rclone
            readonly CONFIG=${lib.escapeShellArg cfg.configPath}
            readonly SOURCE=/persist
            readonly BASE=${lib.escapeShellArg generationRoot}
            readonly RUNTIME_DIR=/run/${serviceName}
            readonly STAMP=$(date -u +%Y%m%dT%H%M%SZ)
            readonly DEST="$BASE/$STAMP"
            readonly LIST="$RUNTIME_DIR/generations.list"

            test -f "$CONFIG"
            ${pkgs.util-linux}/bin/mountpoint --quiet "$SOURCE"
            test -f "$SOURCE/.impermanence-ready"
            test -n "$(${pkgs.findutils}/bin/find "$SOURCE" -mindepth 1 -maxdepth 1 ! -name rollback -print -quit)"

            exec 9>"$RUNTIME_DIR/backup.lock"
            if ! ${pkgs.util-linux}/bin/flock -n 9; then
              echo "${serviceName} is already running" >&2
              exit 0
            fi

            "$RCLONE" copy "$SOURCE" "$DEST" \
              --config="$CONFIG" \
              ${excludeArgs} \
              --fast-list --transfers 4 --checkers 8 \
              --retries 3 --retries-sleep 30s --log-level ERROR --stats 0

            "$RCLONE" check "$SOURCE" "$DEST" \
              --config="$CONFIG" \
              ${excludeArgs} \
              --log-level ERROR --stats 0

            "$RCLONE" lsf "$BASE" --dirs-only --config="$CONFIG" \
              --log-level ERROR --stats 0 > "$LIST"
            cutoff=$(date -u -d "-${toString cfg.retentionDays} days" +%s)
            while IFS= read -r generation; do
              generation=''${generation%/}
              case "$generation" in
                ????????T??????Z)
                  generation_epoch=$(date -u -d "''${generation:0:8} ''${generation:9:2}:''${generation:11:2}:''${generation:13:2}" +%s 2>/dev/null || true)
                  if [ -n "$generation_epoch" ] && [ "$generation_epoch" -lt "$cutoff" ]; then
                    "$RCLONE" delete "$BASE/$generation" --config="$CONFIG" \
                      --rmdirs --log-level ERROR --stats 0
                  fi
                  ;;
              esac
            done < "$LIST"
          '';
        in "${script}";
      };
    };

    systemd.timers.${serviceName} = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 03:30:00";
        Persistent = true;
      };
    };
  };
}
