# infra

Personal NixOS infrastructure managed with Nix flakes, disko, Home Manager,
SOPS, impermanence, Podman, and rclone.

## Hosts

| Host | Role | Storage and services |
| --- | --- | --- |
| `daredevil` | ThinkPad E14 Gen 6 AMD | Desktop, private/media mounts, local `/persist` recovery copy |
| `devil` | Gaming PC | Immich, Jellyfin, Arr stack, Stash, Ollama, libvirt |
| `old-devil` | UPS-backed home server | Home Assistant, Omada, Technitium, private-folder sync |
| `homelab-one` | Hetzner VPS | Caddy, Vaultwarden, StorageBox-to-B2 replica |

## Repository layout

```text
flake.nix                         Inputs, outputs, and host definitions
hosts/                            Per-host NixOS configuration
modules/services/                 Podman and native services
modules/desktop/                  Desktop, GNOME, and persistence policy
modules/impermanence/             Persistence policy and standalone reset scripts
modules/storage/                  rclone configuration and backup helpers
home/                             Home Manager profiles
scripts/                          Installation and bootstrap commands
secrets/                          SOPS-encrypted configuration
tests/                            Build-time and generated-unit validation
```

## Deployment

```bash
sudo nixos-rebuild switch --flake ~/Projects/infra#<hostname>
deploy .#<hostname>
deploy .#
```

The four host configurations are evaluated in CI. The generated persistence
mount units are also checked to ensure they wait for `/persist`.

## Impermanence

Each host uses Btrfs subvolumes for `/`, `/home`, `/nix`, `/swap`, and
`/persist`. `/persist` is the durable local state boundary. The root and home
subvolumes are reset during initrd boot only after the host has a rollback
snapshot and the persistence manifest has been seeded.

The persistence manifest is declared in the host's `storage.nix` file. The
same `myImpermanence.serviceDirectories` list is used by the corresponding
service backup job, so a service state directory is added in one place. Other
durable system paths are listed as `extraSystemDirectories` in the host
configuration.

The reset scripts are separate files under `modules/impermanence/` so their
shell can be linted directly. They create read-only rollback snapshots, copy
only missing declared state into `/persist`, verify markers and subvolumes on
later boots, and switch to empty replacement subvolumes only after all checks
pass. A completion marker is written before old subvolumes are cleaned up on a
later boot, so an interrupted switch can be recovered without deleting the
previous state.

`/etc/machine-id` is the systemd identity of the installation. It is not the
Syncthing device ID. It is persisted so the machine remains the same system
to systemd and services after a reset. SSH host keys, the systemd random seed,
NetworkManager connections, Tailscale state, Bluetooth state, journals, user
configuration, and declared service state are persisted for the same reason.

The SOPS age identity is derived from the host SSH key and stored in
`~/.config/sops/age/keys.txt`. SOPS reads the persisted host key when it is
available and falls back to `/etc/ssh/ssh_host_ed25519_key` during first-boot
setup.

This repository currently targets clean reinstalls for the `@srv` to
`@persist` layout change. A clean `disko` install creates `@persist`; an old
installation with only `@srv` must not be switched to this layout without a
separate migration plan.

## First boot and reinstall

For a normal first boot, run the following as `abhay` before the first reset
reboot:

```bash
./scripts/after_install.sh <hostname> [luks-partition]
```

Examples:

```bash
./scripts/after_install.sh daredevil /dev/nvme0n1p2
./scripts/after_install.sh devil /dev/nvme1n1p2
./scripts/after_install.sh old-devil
./scripts/after_install.sh homelab-one
```

Encrypted hosts can enroll TPM2 when the LUKS partition is supplied. The
server examples only prepare SOPS. The script reuses a valid existing age
identity and supports `--replace-sops-key` only when all affected SOPS
recipients have already been rotated or re-encrypted.

For a full reinstall, first recover the original host SSH key and SOPS age
identity from the protected bootstrap storage. Install the host with disko,
restore the age identity, deploy the configuration, and then restore the
durable state described below. If the original identity is unavailable, the
SOPS recipients must be rotated before encrypted configuration can be
decrypted.

## Local and remote storage

The main rclone configuration uses the encrypted StorageBox remotes:

- `media:` and `immich:` provide mounted media/photo data.
- `private:` stores the encrypted private folder.
- `backups:` stores service and persistence recovery generations.

`homelab-one` uses a second rclone configuration with `b2-storage:` for the
Backblaze B2 copy. Existing data is not renamed or deleted by the new
generation backups. The old flat paths such as `backups:/srv/jellyfin` remain
available. New jobs write below `disaster-recovery/` and prune only timestamped
generations older than 90 days.

## Backup layout

Every generation has a UTC timestamp such as `20260906T043000Z`. A generation
is copied and checked with `rclone check`; it is never used as the destination
of a destructive `sync` operation.

### Generic `/persist` backup

The daily `backup-<host>-persist` job copies the declared contents of `/persist`
to:

```text
StorageBox: backups:/disaster-recovery/<host>/persist/<timestamp>/
B2:        b2-storage:/disaster-recovery/homelab-one/persist/<timestamp>/
```

It excludes local rollback snapshots, caches, generated database files, and
the Ollama model cache on `devil`. It therefore contains the durable system
and user configuration, secrets-related state, and non-database service files.
Database recovery comes from the service backup generations below.

### Service backup matrix

| Host | Location | Contents |
| --- | --- | --- |
| `devil` | `backups:/disaster-recovery/devil/services/<timestamp>/` | Immich PostgreSQL dump; Jellyfin, Sonarr, Radarr, Whisparr, Seerr, and Stash with SQLite exports; Prowlarr, SABnzbd, downloads, Gluetun, qBittorrent, and libvirt as file trees |
| `old-devil` | `backups:/disaster-recovery/old-devil/services/<timestamp>/` | Home Assistant with SQLite exports; Omada and Technitium file trees, captured while those services are stopped and restarted afterward |
| `homelab-one` | `b2-storage:/disaster-recovery/homelab-one/services/<timestamp>/` | Vaultwarden with SQLite exports and Caddy state |
| `daredevil` | no service-generation job | Covered by the generic `/persist` backup |

SQLite files are exported with SQLite's backup API and checked with
`PRAGMA integrity_check`. The live SQLite file and WAL/SHM sidecars are not
treated as independent databases. The service generation contains the
non-database files plus the consistent exported database at the same relative
path, making a tree restore straightforward.

`old-devil` also syncs `~/Sync/Private` hourly to `private:`. Changes moved by
that sync are retained under `private:private-history/<timestamp>/`. This job
is still required because the private folder originates on `old-devil`; the
service backups on `devil` do not contain it.

`homelab-one` additionally mirrors the complete `homelab-storage-one:` remote
to `b2-storage:homelab-storage-one-replica/`. Files removed or replaced by the
mirror are first placed in
`b2-storage:homelab-storage-one-replica-history/<timestamp>/`.

## Restore patterns

Use the rclone configuration for the host being restored and select a
timestamped generation. Stop the affected service before copying its files.

```bash
REMOTE='backups:/disaster-recovery/devil/services/20260906T040000Z'
rclone copy "$REMOTE/jellyfin" /srv/jellyfin --config "$RCLONE_CONFIG"
rclone copy "$REMOTE/sonarr" /srv/sonarr --config "$RCLONE_CONFIG"
```

For a SQLite-backed service, the exported database is already included at its
original relative path. Restore the whole service directory, then start the
container. For Immich PostgreSQL, restore the compressed dump after the empty
database container is running:

```bash
rclone copy "$REMOTE/immich/postgres/immich-db.sql.gz" /tmp --config "$RCLONE_CONFIG"
gunzip -c /tmp/immich-db.sql.gz | podman exec -i immich-database psql -U postgres immich
```

For a complete host recovery:

1. Reinstall with the matching disko host configuration.
2. Recover the host SSH key and SOPS age identity, then run `after_install.sh`.
3. Deploy once so `/persist` and the service directories exist.
4. Restore the selected `/persist/<timestamp>/` generation.
5. Restore service-generation trees and the Immich database dump where needed.
6. Start services and verify their data, credentials, mounts, and logs.
7. Keep the old generation until the restored host has been tested.

Do not delete the old `backups:/srv/*`, `private:`, or B2 replica trees as part
of this migration. They are fallback copies. Delete them only after a tested
restore and an explicit storage-retention decision.

## Container lifecycle and hardening

NixOS owns the Podman systemd units. `autoRemoveOnStop = false` keeps the
managed container object available across restarts; container-level
`--restart=always` flags are intentionally absent because restart behavior
belongs to systemd. Containers use shared hardening options where compatible:
no-new-privileges, dropped capabilities, read-only roots, temporary filesystems,
and resource limits. Services that need a writable database or special device
access opt out of only the incompatible parts.

## Desktop notes

Desktop credentials, Git SSH signing, and host SSH aliases are imported only
by the desktop control-room role. Server Home Manager profiles keep the common
Git/SSH baseline without receiving desktop credentials.

The wallpaper selection is not tied to the repository. GNOME uses
`~/.local/share/backgrounds/current-wallpaper`; change it on any host without
rebuilding NixOS:

```bash
set-wallpaper /path/to/image.png
```

## Neovim and workflows

The nixvim configuration lives in its own repository:
[nixvim-config](https://github.com/abhayprabhakarannair/nixvim-config).

Desktop profiles include `gh`; authenticate once per machine. Git commits use
SSH signing and Git verifies signatures against the configured allowed
signers file.
