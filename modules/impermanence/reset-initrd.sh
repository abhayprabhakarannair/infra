#!/usr/bin/env bash
set -eu

impermanence_btrfs_device=@device@
impermanence_btrfs_root=/run/impermanence-btrfs-root
impermanence_subvolumes="@ @home"
impermanence_reset_complete=no
mkdir -p "$impermanence_btrfs_root"

cleanup() {
  impermanence_status=$?

  if [ "$impermanence_reset_complete" != yes ]; then
    for impermanence_subvolume in $impermanence_subvolumes; do
      if @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
        if @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
          @btrfs@ subvolume delete "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
        fi
        @btrfs@ subvolume rename \
          "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" \
          "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
      elif @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1; then
        @btrfs@ subvolume delete \
          "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1 || true
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

for impermanence_subvolume in @ @home; do
  if @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
    if @btrfs@ subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
      @btrfs@ subvolume delete "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
    fi
    @btrfs@ subvolume rename \
      "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" \
      "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
    log "recovered interrupted reset for $impermanence_subvolume"
  fi
done

if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-ready" ]; then
  log "migration marker absent; keeping existing subvolumes"
  exit 0
fi

if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-state-seeded-v3" ]; then
  log "state migration marker v3 absent; refusing destructive reset"
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

for impermanence_subvolume in $impermanence_subvolumes; do
  @btrfs@ subvolume delete \
    "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old"
done

sync
impermanence_reset_complete=yes
log "subvolume reset complete"
