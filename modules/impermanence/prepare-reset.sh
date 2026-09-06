#!/usr/bin/env bash
set -eu

marker=/persist/.impermanence-ready
rollback=/persist/rollback
migration_marker=/persist/.impermanence-state-seeded-v3

seed_file() {
  source="$1"
  target="$2"
  if [ -e "$source" ] && [ ! -e "$target" ] && [ ! -L "$target" ]; then
    @mkdir@ -p "$( @dirname@ "$target" )"
    @cp@ -a -- "$source" "$target"
  fi
}

seed_directory() {
  source="$1"
  target="$2"
  [ -d "$source" ] || return 0
  @mkdir@ -p "$target"

  for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name="${entry##*/}"
    if [ ! -e "$target/$name" ] && [ ! -L "$target/$name" ]; then
      @cp@ -a -- "$entry" "$target/$name"
    fi
  done
}

seed_declared_state() {
@seedSystemDirectories@
@seedServiceDirectories@
@seedHomeDirectories@
@seedSystemFiles@
@seedHomeFiles@
@seedHomeOwnership@
}

if ! @mountpoint@ --quiet /persist; then
  echo "impermanence-prepare-reset: /persist is not mounted" >&2
  exit 1
fi

has_snapshot=no
latest_snapshot=
for candidate in "$rollback"/*; do
  if @btrfs@ subvolume show "$candidate/root" >/dev/null 2>&1 && \
    @btrfs@ subvolume show "$candidate/home" >/dev/null 2>&1; then
    has_snapshot=yes
    latest_snapshot="$candidate"
  fi
done

if [ -e "$marker" ] && [ "$has_snapshot" = yes ]; then
  if [ ! -e "$migration_marker" ]; then
    destination="$latest_snapshot"
    seed_declared_state
    @touch@ "$migration_marker"
  fi
  exit 0
fi

stamp=$(@date@ -u +%Y%m%d-%H%M%S)
destination="$rollback/$stamp"
@mkdir@ -p "$destination"

@btrfs@ subvolume snapshot -r / "$destination/root"
@btrfs@ subvolume snapshot -r /home "$destination/home"

if [ -d /srv ] && @btrfs@ subvolume show /srv >/dev/null 2>&1; then
  @btrfs@ subvolume snapshot -r /srv "$destination/srv"
fi

seed_declared_state
@touch@ "$migration_marker"
@touch@ "$marker"
echo "Created read-only rollback snapshots under $destination"
