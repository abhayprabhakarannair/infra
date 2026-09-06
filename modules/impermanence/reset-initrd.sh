#!/usr/bin/env bash
set -eu

impermanence_btrfs_device=@device@
impermanence_btrfs_root=/run/impermanence-btrfs-root
impermanence_subvolumes="@ @home"
impermanence_reset_complete=no
impermanence_reset_marker="$impermanence_btrfs_root/@persist/.impermanence-reset-complete-v1"
mkdir -p "$impermanence_btrfs_root"

cleanup() {
  impermanence_status=$?

  if [ "$impermanence_reset_complete" != yes ]; then
    for impermanence_subvolume in $impermanence_subvolumes; do
      impermanence_current="$impermanence_btrfs_root/$impermanence_subvolume"
      impermanence_old="$impermanence_current.impermanence-old"
      impermanence_new="$impermanence_current.impermanence-new"
      if @btrfs@ subvolume show "$impermanence_old" >/dev/null 2>&1; then
        if @btrfs@ subvolume show "$impermanence_current" >/dev/null 2>&1; then
          @btrfs@ subvolume delete "$impermanence_current" >/dev/null 2>&1 || true
        fi
        if @btrfs@ subvolume show "$impermanence_new" >/dev/null 2>&1; then
          @btrfs@ subvolume delete "$impermanence_new" >/dev/null 2>&1 || true
        fi
        @btrfs@ subvolume rename "$impermanence_old" "$impermanence_current" >/dev/null 2>&1 || true
      elif @btrfs@ subvolume show "$impermanence_new" >/dev/null 2>&1; then
        @btrfs@ subvolume delete "$impermanence_new" >/dev/null 2>&1 || true
      fi
    done
  fi

  if @mountpoint@ --quiet "$impermanence_btrfs_root"; then
    @umount@ "$impermanence_btrfs_root" \
      || @umount@ --lazy "$impermanence_btrfs_root" \
      || true
  fi

  trap - EXIT
  exit "$impermanence_status"
}
trap cleanup EXIT

@mount@ -t btrfs -o subvolid=5 "$impermanence_btrfs_device" "$impermanence_btrfs_root"

if ! @btrfs@ subvolume show "$impermanence_btrfs_root/@persist" >/dev/null 2>&1; then
  echo "impermanence-reset: @persist is not a Btrfs subvolume" >&2
  exit 1
fi

impermanence_log="$impermanence_btrfs_root/@persist/.impermanence-reset.log"
exec 9>>"$impermanence_log"
log() { echo "impermanence-reset: $*" >&9; }
log "mounted top-level Btrfs"

if [ -e "$impermanence_reset_marker" ]; then
  for impermanence_subvolume in $impermanence_subvolumes; do
    impermanence_current="$impermanence_btrfs_root/$impermanence_subvolume"
    if ! @btrfs@ subvolume show "$impermanence_current" >/dev/null 2>&1; then
      log "completed reset is missing $impermanence_subvolume"
      exit 1
    fi
  done
  impermanence_reset_complete=yes
  for impermanence_subvolume in $impermanence_subvolumes; do
    impermanence_current="$impermanence_btrfs_root/$impermanence_subvolume"
    for impermanence_suffix in impermanence-old impermanence-new; do
      impermanence_leftover="$impermanence_current.$impermanence_suffix"
      if @btrfs@ subvolume show "$impermanence_leftover" >/dev/null 2>&1; then
        @btrfs@ subvolume delete "$impermanence_leftover"
      fi
    done
  done
  for impermanence_subvolume in $impermanence_subvolumes; do
    impermanence_current="$impermanence_btrfs_root/$impermanence_subvolume"
    for impermanence_suffix in impermanence-old impermanence-new; do
      impermanence_leftover="$impermanence_current.$impermanence_suffix"
      if @btrfs@ subvolume show "$impermanence_leftover" >/dev/null 2>&1; then
        log "reset cleanup is still pending for $impermanence_subvolume"
        exit 0
      fi
    done
  done
  @rm@ -f -- "$impermanence_reset_marker"
  log "completed reset cleanup"
  exit 0
fi

for impermanence_subvolume in @ @home; do
  impermanence_current="$impermanence_btrfs_root/$impermanence_subvolume"
  impermanence_old="$impermanence_current.impermanence-old"
  impermanence_new="$impermanence_current.impermanence-new"
  if @btrfs@ subvolume show "$impermanence_old" >/dev/null 2>&1; then
    if @btrfs@ subvolume show "$impermanence_current" >/dev/null 2>&1; then
      @btrfs@ subvolume delete "$impermanence_current"
    fi
    if @btrfs@ subvolume show "$impermanence_new" >/dev/null 2>&1; then
      @btrfs@ subvolume delete "$impermanence_new"
    fi
    @btrfs@ subvolume rename "$impermanence_old" "$impermanence_current"
    log "recovered interrupted reset for $impermanence_subvolume"
  elif @btrfs@ subvolume show "$impermanence_new" >/dev/null 2>&1; then
    @btrfs@ subvolume delete "$impermanence_new"
  fi
done

if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-ready" ]; then
  log "migration marker absent; keeping existing subvolumes"
  exit 0
fi

if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-state-seeded-v4" ]; then
  log "state migration marker v4 absent; refusing destructive reset"
  exit 1
fi

impermanence_latest_snapshot=
for impermanence_candidate in "$impermanence_btrfs_root/@persist/rollback"/*; do
  if @btrfs@ subvolume show "$impermanence_candidate/root" >/dev/null 2>&1 && \
    @btrfs@ subvolume show "$impermanence_candidate/home" >/dev/null 2>&1; then
    impermanence_latest_snapshot="$impermanence_candidate"
  fi
done
if [ -z "$impermanence_latest_snapshot" ]; then
  log "no complete rollback snapshot found; refusing destructive reset"
  exit 1
fi

@preflightPersistentDirectories@

for impermanence_subvolume in $impermanence_subvolumes; do
  if ! @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
    log "required subvolume is missing: $impermanence_subvolume"
    exit 1
  fi
  if @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1 || \
    @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
    log "transactional reset names already exist for $impermanence_subvolume"
    exit 1
  fi
done

for impermanence_subvolume in $impermanence_subvolumes; do
  @btrfs@ subvolume create \
    "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new"
done

for impermanence_subvolume in $impermanence_subvolumes; do
  @btrfs@ subvolume rename \
    "$impermanence_btrfs_root/$impermanence_subvolume" \
    "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old"
  @btrfs@ subvolume rename \
    "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" \
    "$impermanence_btrfs_root/$impermanence_subvolume"
  log "switched $impermanence_subvolume"
done

@touch@ "$impermanence_reset_marker"
sync
impermanence_reset_complete=yes
log "subvolume reset complete; old subvolumes queued for cleanup"
