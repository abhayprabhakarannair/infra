# homelab-one Audit & Cleanup — Aug 2026

Session notes from a full health-check of the `homelab-one` host (Hetzner VPS).
Captures findings, what was fixed, what was deliberately deferred, and specs/baseline
numbers for future comparison.

## Host specs (as of audit)

- Hetzner vServer, Intel Xeon (Skylake), **2 vCPU / 3.7GB RAM / 4GB swap**
- Disk: **39GB** (`/dev/sda2`, single btrfs-ish partition, everything on one fs)
- NixOS 26.05, kernel 6.18.x
- Load avg was 0.14–0.22 on 2 cores — plenty of CPU/RAM headroom
- **Disk is the actual constraint on this box, not CPU/RAM**

## Services running (all healthy at time of audit)

| Service | Type | CPU % | Mem | Notes |
|---|---|---|---|---|
| caddy | native | low | small | reverse proxy for ALL domains, including devil/old-devil backends |
| forgejo | podman | ~4% | ~157MB | `git.iamabhay.fyi`, SSH on 2222 |
| forgejo-runner | native | — | — | CI runner, capacity=3 |
| vaultwarden | podman | ~0% | ~27MB | pinned 1.37.1 |
| grafana | podman | ~1.5% | ~327MB | |
| prometheus | podman | ~1.8% | ~169MB | `--web.enable-remote-write-receiver`, now `--storage.tsdb.retention.time=30d` |
| loki | podman | ~1.6% | ~116MB | 14d retention configured in loki.yaml |
| alloy | native | — | — | ships metrics/logs from devil + old-devil into this box's loki/prometheus |

Total container footprint was ~800MB RAM / ~10% combined CPU — box could run several
more services this size without issue.

## Findings & what was done

### 1. Disk was at 77% (29G/39G used) — FIXED
Root cause: 16,776 dead nix-store paths sitting around because `nix.gc` was only
configured fleet-wide (`modules/core/default.nix`) with `--delete-older-than 14d`,
and generations pile up faster than that clears on a low-traffic box with weekly GC.

**Action taken (manual, one-time):** `nix-collect-garbage -d` → freed **20.1GB**.
Disk went from **77% → 45%**.

**Config fix (committed):** `hosts/homelab-one/default.nix` now overrides GC to
`--delete-older-than 7d` via `lib.mkForce` (host-specific override, other hosts
still on the shared 14d default — homelab-one's disk is just smaller so it needs
tighter retention). Also added `boot.loader.grub.configurationLimit = 5` (was
unbounded, had 8 generations sitting in grub).

### 2. Caddy access logs were unbounded — FIXED
`/var/log/caddy` had grown to **1.1GB**. Some single domain log files were 90MB+
(e.g. `access-prometheus.iamabhay.fyi.log` at 96MB, `access-git...log` at 87MB).
Root cause: `modules/services/caddy.nix` templated `output file` with zero rotation
config (`roll_size`/`roll_keep`).

**Config fix (committed):** Added `roll_size 10mb`, `roll_keep 5`, `roll_keep_for
168h` to every vhost's log block in `modules/services/caddy.nix`.

**Gotcha found & fixed in the same change:** the NixOS `services.caddy` module
auto-generates its *own* default per-vhost log block (`hostOpts.logFormat`) that
also writes to `/var/log/caddy/access-<domain>.log`. Our custom `extraConfig` log
block was writing to the *same file*, meaning every vhost had two independent log
writers pointed at one file — a correctness bug, not just cosmetic. Fixed by
setting `logFormat = null;` per vhost to disable the module's default and rely
solely on our custom block. Verified via `caddy validate` that the generated
Caddyfile now has exactly one `log {}` block per vhost.

### 3. Dead log files on disk — FIXED (manual, one-time)
- 15 zero-byte legacy log files (`access-grafana.log`, `access-jellyfin.log`, etc.
  — the non-domain-qualified ones, never written to) — deleted.
- `access-chat.iamabhay.fyi.log` (47MB) — leftover from Open WebUI, which was
  removed in commit `a59bc27` but its Caddy log was never cleaned up — deleted.
- 16 rotated `.gz` caddy logs older than 30 days — deleted.

### 4. Prometheus had no retention limit — FIXED
`modules/services/grafana/default.nix` prometheus container had
`--web.enable-remote-write-receiver` but no explicit retention flag (defaults to
15d, but was undocumented/implicit). Data was already 1.8GB after ~2 months with
only 3 hosts feeding it via alloy.

**Config fix (committed):** Added `--storage.tsdb.retention.time=30d` explicitly.

### 5. Dead sops secret — FOUND, NOT FIXED (deliberately deferred)
`modules/services/caddy.nix` declares `sops.secrets."caddy/basic-auth-password"`
but it is **never referenced** in any `virtualHosts` config — no `basicauth`
directive anywhere. Almost certainly leftover from the removed Open WebUI /chat
setup (same era as the dead `access-chat...log` file above).

**Status: intentionally left alone per Abhay's request — "plans for later".**
Do not remove without checking in first; there may be a reason it's still wanted
(e.g. reused for a future basic-auth-gated service).

## What was NOT touched / not a problem

- Loki: already has sane retention (`retention_period: 14d` in `loki.yaml`) with
  compactor enabled. Fine as-is.
- Forgejo, vaultwarden: healthy, small footprint, pinned image versions, no action needed.
- forgejo-runner: healthy, connected, capacity=3 — fine for current CI load.
- Backups (`hosts/homelab-one/storage.nix`): nightly 02:00 timer syncing
  `/srv/{vaultwarden,forgejo,grafana}` → Hetzner StorageBox → B2, confirmed
  last run succeeded (`Aug 25 02:01:17`, exit 0/SUCCESS).
- alloy hub/node split (grafana/alloy-hub.nix on homelab-one, alloy-node.nix on
  devil + old-devil) — clean, sensible design. Not touched.

## Changes shipped

**Branch:** `homelab-one-cleanup-aug2026` → PR **#58** → CI passed → merged to
`main` → deployed via `deploy .#homelab-one` (magic rollback confirmed, no rollback
needed).

**Files changed:**
- `hosts/homelab-one/default.nix` — `nix.gc.options` override (7d), grub
  `configurationLimit = 5`
- `modules/services/caddy.nix` — per-vhost `logFormat = null` + rotation config in
  custom log block
- `modules/services/grafana/default.nix` — prometheus `--storage.tsdb.retention.time=30d`

**Manual one-time actions on the box (not in git, won't repeat automatically):**
- `nix-collect-garbage -d` (20.1GB freed)
- Deleted 15 zero-byte + 1 stale (chat) + 16 old `.gz` caddy log files

## Post-deploy verification (all passed)

- `systemctl --failed` → 0 units
- caddy active, rendered Caddyfile confirmed single log block per vhost with
  rotation directives present
- prometheus container confirmed running with new `--storage.tsdb.retention.time=30d` flag
- `vault.iamabhay.fyi`, `git.iamabhay.fyi`, `grafana.iamabhay.fyi` all returned
  healthy HTTP responses (200/302) post-deploy
- Disk: **45% used** (was 77% pre-cleanup)

## Baseline numbers for future comparison

- Disk: 45% used (17G/39G) as of this audit — re-check if it creeps back toward 70%+
- `/srv` sizes at audit time: forgejo 143M, grafana 75M, loki 2.6M, prometheus 1.8G
  (before retention flag took effect), vaultwarden 1.6M
- journald: capped at 1G (`SystemMaxUse=1G` in `modules/core/default.nix`), was
  using 932M
- nix store closure size: ~24GB pre-GC pass, ~67GB total closure size reported by
  `nix path-info --closure-size -r /run/current-system` (this counts all
  referenced deps, not disk-unique size)

## Open items / ideas for next session

- [ ] Decide fate of dead `caddy/basic-auth-password` sops secret (see #5 above)
- [ ] Consider whether Prometheus 30d retention is enough once more alloy-node
  hosts get added (currently devil + old-devil only)
- [ ] Watch disk usage trend over next few weeks now that 7d GC + log rotation
  are in place — confirm it stays stable instead of creeping back up
- [ ] No monitoring/alerting on disk usage itself was found — could be worth a
  Prometheus node-exporter disk alert rule now that grafana/prometheus/loki are
  all healthy and have headroom
