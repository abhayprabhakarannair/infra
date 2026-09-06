infra_rclone_copy_checked() {
  local source="$1"
  local destination="$2"
  local rclone_config="$3"
  shift 3

  rclone copy "$source" "$destination" \
    --config="$rclone_config" --retries 3 --retries-sleep 30s \
    --log-level ERROR --stats 0 "$@"
  rclone check "$source" "$destination" \
    --config="$rclone_config" --log-level ERROR --stats 0 "$@"
}

infra_require_dir() {
  local directory="$1"
  test -d "$directory"
}

infra_export_sqlite_tree() {
  local source="$1"
  local staging_root="$2"
  local relative_service="$3"
  local destination="$4"
  local rclone_config="$5"
  local database relative output

  while IFS= read -r -d "" database; do
    relative="${database#"$source"/}"
    output="$staging_root/$relative_service/$relative"
    mkdir -p "$(dirname "$output")"
    sqlite3 "$database" ".backup '$output'"
    test -s "$output"
    sqlite3 "$output" "PRAGMA integrity_check;" | grep -Fxq ok
  done < <(find "$source" -type f \( \
    -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \
  \) -print0)

  test -d "$staging_root/$relative_service" || return 0
  infra_rclone_copy_checked "$staging_root/$relative_service" "$destination" "$rclone_config"
}

infra_backup_sqlite_service() {
  local source="$1"
  local staging_root="$2"
  local relative_service="$3"
  local destination="$4"
  local rclone_config="$5"

  infra_rclone_copy_checked "$source" "$destination" "$rclone_config" \
    --fast-list --transfers 4 --checkers 8 \
    --exclude '**/*.db' --exclude '**/*.db-*' \
    --exclude '**/*.sqlite' --exclude '**/*.sqlite-*' \
    --exclude '**/*.sqlite3'
  infra_export_sqlite_tree "$source" "$staging_root" "$relative_service" "$destination" "$rclone_config"
}

infra_backup_tree() {
  local source="$1"
  local destination="$2"
  local rclone_config="$3"

  infra_rclone_copy_checked "$source" "$destination" "$rclone_config" \
    --fast-list --transfers 4 --checkers 8
}

infra_prune_generations() {
  local base="$1"
  local rclone_config="$2"
  local retention_days="$3"
  local listing="$4"
  local generation generation_epoch cutoff

  rclone lsf "$base" --dirs-only \
    --config="$rclone_config" --log-level ERROR --stats 0 > "$listing"
  cutoff=$(date -u -d "-$retention_days days" +%s)
  while IFS= read -r generation; do
    generation="${generation%/}"
    case "$generation" in
      ????????T??????Z)
        generation_epoch=$(date -u -d "${generation:0:8} ${generation:9:2}:${generation:11:2}:${generation:13:2}" +%s 2>/dev/null || true)
        if [ -n "$generation_epoch" ] && [ "$generation_epoch" -lt "$cutoff" ]; then
          rclone delete "$base/$generation" \
            --config="$rclone_config" --rmdirs --log-level ERROR --stats 0
        fi
        ;;
    esac
  done < "$listing"
}
