# infra

Personal NixOS infrastructure.

## Hosts

| Host | Role | Location |
|------|------|----------|
| `daredevil` | ThinkPad E14 Gen 6 AMD (21M4) | Daily driver |
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

### First-boot SOPS setup

After the first reboot, derive the SOPS age identity from the host SSH key:

```bash
./scripts/after_install.sh <hostname> <luks-partition>
```

The script stores it at `~/.config/sops/age/keys.txt` with mode `0600`, validates and reuses an existing identity on reruns, and removes failed-run temporary files. Use `--replace-sops-key` only after rotating or re-encrypting the affected SOPS recipients and confirming the old identity is no longer required. TPM2 enrollment runs only after SOPS setup completes, so a failed TPM enrollment can be retried safely. If the identity is lost, restore it from the protected bootstrap backup or rotate the host's SOPS recipient before attempting decryption.

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
