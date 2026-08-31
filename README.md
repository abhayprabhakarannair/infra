# infra

Personal NixOS infrastructure.

## Hosts

| Host | Role | Location |
|------|------|----------|
| `daredevil` | ThinkPad X1 Carbon | Daily driver |
| `devil` | Gaming PC | Home |
| `old-devil` | Home server | Home (UPS-backed) |
| `homelab-one` | VPS | Hetzner Falkenstein |

## Structure

```
flake.nix          # Inputs, outputs, deploy-rs config
hosts/             # Per-host NixOS configs
modules/           # Shared NixOS modules
  services/        # Container services (vaultwarden, immich, etc.)
  desktop/         # Desktop-specific (nixvim, etc.)
  storage/         # Rclone mounts, backups
home/              # Home-manager configs (shared + per-host)
secrets/           # Sops-encrypted secrets
```

## Deploy

```bash
# Local rebuild
sudo nixos-rebuild switch --flake ~/Projects/infra#<hostname>

# Remote deploy with rollback
deploy .#<hostname>
deploy .#                # all hosts
```

## Storage

- **Hetzner StorageBox** (1TB): primary backing store via rclone crypt
  - `media:`, `immich:`, `private:`, `backups:` — all encrypted
  - Mounted at `/mnt/homelab/` on devil
- **Backblaze B2**: nightly replica of StorageBox
- **Backups**: nightly /srv/ backups via rclone → StorageBox → B2

## Key Services

- **Vaultwarden** (password manager) — homelab-one
- **Immich** (photos) — devil
- **Jellyfin** (media and FLAC music for Symfonium) — devil
- **Home Assistant** — old-devil
- **Arr-stack** (sonarr, radarr, prowlarr, sabnzbd, qbittorrent) — devil

## Neovim

The nixvim configuration lives in its own repo:
https://github.com/abhayprabhakarannair/nixvim-config

Infra imports it as a flake input — edit there, both infra and WSL pick up changes.

## GitHub workflows

- Desktop profiles include the GitHub CLI (`gh`). Run `gh auth login` once per machine and select SSH for Git operations.
- Git commits use SSH signing and Git verifies signatures against the configured allowed signers file.
