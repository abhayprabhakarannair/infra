{
  config,
  pkgs,
  inputs,
  ...
}: {
  environment.etc."infra/backup-lib.sh".text = ''
    # Shared, non-secret helpers for storage backup units. Callers must pass
    # the already-declared rclone config path; this file never reads secrets.
    set -u

    infra_rclone_copy_checked() {
      local source="$1"
      local destination="$2"
      local rclone_config="$3"
      shift 3

      ${pkgs.rclone}/bin/rclone copy "$source" "$destination" \
        --config="$rclone_config" --retries 3 --retries-sleep 30s \
        --log-level ERROR --stats 0 "$@"
      ${pkgs.rclone}/bin/rclone check "$source" "$destination" \
        --config="$rclone_config" --log-level ERROR --stats 0 "$@"
    }

    # An empty declared directory is valid on a fresh or lightly-used host;
    # the important fail-closed condition is that the mount/source exists.
    infra_require_dir() {
      local directory="$1"
      test -d "$directory"
    }

    # Export every SQLite database below a service directory using SQLite's
    # online backup API. The caller must exclude database files from the
    # ordinary tree copy, then upload the returned staging tree.
    infra_export_sqlite_tree() {
      local source="$1"
      local staging_root="$2"
      local relative_service="$3"
      local destination="$4"
      local rclone_config="$5"
      local database relative output

      while IFS= read -r -d "" database; do
        relative="''${database#"$source"/}"
        output="$staging_root/$relative_service/$relative"
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$output")"
        ${pkgs.sqlite}/bin/sqlite3 "$database" ".backup '$output'"
        test -s "$output"
        ${pkgs.sqlite}/bin/sqlite3 "$output" "PRAGMA integrity_check;" | ${pkgs.gnugrep}/bin/grep -Fxq ok
      done < <(${pkgs.findutils}/bin/find "$source" -type f \( \
        -name '*.db' -o -name '*.db-*' -o -name '*.sqlite' -o \
        -name '*.sqlite-*' -o -name '*.sqlite3' \
      \) -print0)

      test -d "$staging_root/$relative_service" || return 0
      infra_rclone_copy_checked "$staging_root/$relative_service" "$destination" "$rclone_config"
    }

    # Generations are timestamped directories. Retention is evaluated from
    # the directory name, so old source mtimes can never remove fresh data.
    # Restore drills must copy one generation to a new temporary directory,
    # run the database integrity checks there, and compare the manifest before
    # any operator considers a live restore. No helper in this file writes to
    # a service's live data directory.
    infra_prune_generations() {
      local base="$1"
      local rclone_config="$2"
      local retention_days="$3"
      local listing="$4"
      local generation generation_epoch cutoff

      ${pkgs.rclone}/bin/rclone lsf "$base" --dirs-only \
        --config="$rclone_config" --log-level ERROR --stats 0 > "$listing"
      cutoff=$(date -u -d "-$retention_days days" +%s)
      while IFS= read -r generation; do
        generation="''${generation%/}"
        case "$generation" in
          20??????T??????Z)
            generation_epoch=$(date -u -d "''${generation:0:8} ''${generation:9:2}:''${generation:11:2}:''${generation:13:2}" +%s 2>/dev/null || true)
            if [ -n "$generation_epoch" ] && [ "$generation_epoch" -lt "$cutoff" ]; then
              ${pkgs.rclone}/bin/rclone delete "$base/$generation" \
                --config="$rclone_config" --rmdirs --log-level ERROR --stats 0
            fi
            ;;
        esac
      done < "$listing"
    }
  '';

  sops.secrets."known-hosts" = {
    sopsFile = "${inputs.self}/secrets/rclone/secrets.yaml";
    path = "/etc/rclone/known_hosts";
    owner = "root";
    group = "users";
    mode = "0440";
  };
}
