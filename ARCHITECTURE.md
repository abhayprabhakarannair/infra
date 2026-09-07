# Infrastructure Re-architecture

This repository is being rebuilt from a smaller foundation. The files under
`legacy/` describe the existing five-fleet homelab and remain a reference for
features, service requirements, and recovery procedures. They are not the
architecture to port wholesale.

`daredevil` is the first real implementation of the new design. It is a
laptop with the new persistence model, desktop experience, application set,
and deployment workflow. `devil` will reuse that foundation and add gaming,
ARR, Immich, Jellyfin, Stash, Ollama, and the related storage workloads.

## Design goals

- Rebuild hosts from declarative configuration.
- Make a system safe to reinstall or intentionally nuke.
- Keep persistent data and machine identity explicit.
- Keep containers and other reproducible runtime state disposable.
- Design storage and backups around workload performance.
- Keep host files small by composing shared modules with host-specific parts.

## Host structure

The host file should describe composition. Shared behavior belongs in modules.

```text
modules/
  foundation/
  desktop/niri/
  hardware/laptop/
  persistence/
  storage/
  podman/
  services/
    arr/
    immich/
    media/
    ollama/
    gaming/

hosts/
  daredevil/
    default.nix
    hardware.nix
    disko.nix
    preservation.nix
  devil/
    default.nix
    hardware.nix
    disko.nix
    preservation.nix
```

`daredevil` and `devil` should share the desktop and foundation modules. Their
differences should be visible in their host files: hardware, disks, enabled
workloads, and performance policy.

## Persistence model

The new model uses an ephemeral root and explicit persistent filesystems.
`daredevil` currently has an encrypted Btrfs layout with `/` on tmpfs and
`/persistent` on a durable subvolume. `preservation` recreates selected
directories and files during boot.

Persistent data is divided by purpose:

```text
identity/
  SSH host keys, machine identity, recovery material

services/
  ARR, Immich, Jellyfin, Stash, and other service configuration

databases/
  PostgreSQL data or verified database dumps

user-data/
  Home directory and irreplaceable user files

media/
  The authoritative media and Immich library location

cache/
  Rebuildable caches, model caches, thumbnails, and temporary data
```

The whole `/home/abhay` directory remains persistent while the new desktop and
application set is changing. Narrowing it prematurely creates migration work
and loses application state. It can be split into explicit user data and
application state after the new environment is stable.

Container images, containers, logs, and caches should eventually be
disposable. The current preservation of `/var/lib/containers` on `daredevil`
is transitional convenience while the foundation is being developed. The
long-term model for `devil` is to preserve bind-mounted service data and
recreate the container runtime declaratively.

## Devil workloads

### ARR

ARR services should share a consistent path namespace so imports and moves do
not cause unnecessary copies:

```text
/media
  downloads/
  movies/
  tv/
  music/

/persistent/services/arr
  gluetun/
  qbittorrent/
  prowlarr/
  sonarr/
  radarr/
  seerr/
  whisparr/
```

The service configuration is persistent. The containers are disposable.
Gluetun, qBittorrent, and dependent services need explicit systemd ordering
and network relationships.

### Immich

Immich needs a deliberate performance layout:

- PostgreSQL on local fast storage.
- The Immich library on its authoritative storage location.
- Machine-learning model cache on fast disposable storage.
- GPU access declared explicitly.
- PostgreSQL dumps made before backup.

If the library lives on homelab storage mounted by rclone, that storage owns
the library backup. Devil must not back up a second copy of the same remote
media through the mount.

## Backup strategy

The legacy backup implementation already has useful behavior: scheduled
backups, database-aware SQLite copies, an Immich PostgreSQL dump, transfer
verification, completed-generation markers, and retention pruning.

The new implementation should keep the operational simplicity but use Restic
as the backup engine. Rclone remains the mount and transport tool where it is
needed, but should not remain the custom snapshot/versioning layer.

Restic provides encrypted, deduplicated snapshots with integrity checking and
retention operations. See the [Restic backup documentation](https://restic.readthedocs.io/en/stable/040_backup.html).

Use one repository for the fleet on the existing backup target. Each host gets
one daily systemd timer. Start with this retention policy:

```text
7 daily snapshots
4 weekly snapshots
6 monthly snapshots
```

Each host backup should contain only intentional persistent data:

```text
/persistent/identity
/persistent/services
/persistent/databases
/home/abhay            # initially for daredevil
/run/backup/*.dump     # generated database dumps
```

Do not back up:

- `/var/lib/containers`;
- container images or containers;
- rclone VFS cache;
- Immich thumbnails and machine-learning cache;
- rebuildable Ollama models;
- remote media already backed up by its authoritative storage host;
- downloads unless unfinished downloads are intentionally valuable.

Database handling remains explicit. SQLite services use SQLite's online
backup mechanism. Immich uses `pg_dump` from PostgreSQL. The dump must be
verified before it is included in the Restic snapshot.

The backup job should fail if a declared source is missing. It should run the
database dumps, create one Restic snapshot, apply the retention policy, and
periodically run `restic check`. A restore procedure is part of the design:
rebuild the host, recreate mounts and services from Nix, restore persistent
data, and start the services.

Local Btrfs snapshots may be used for quick rollback, but they are not a
backup. The Restic repository is the disaster-recovery copy.

## Migration rule

When moving a legacy feature, first record:

1. What user or service capability it provides.
2. Which data is authoritative.
3. Which state must survive a rebuild.
4. Which state can be recreated.
5. How that data is restored on a clean host.

Then implement the capability in the new module structure. Do not copy the
legacy impermanence, mount, or backup abstractions without checking whether
they still fit the new persistence and performance model.
