{pkgs, inputs, config, ...}:

{
  imports = [
   "${inputs.self}/modules/storage/main.nix"
   "${inputs.self}/modules/syncthing"
  ];

  systemd.tmpfiles.rules = [ "d /mnt/homelab 0750 1000 1000 -" ];

  systemd.services = {
   rclone-homelab = {
      description = "Rclone mount for Encrypted Homelab Storage One";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/homelab || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/homelab
      '';

      serviceConfig = {
        Type = "notify";
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/homelab; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount homelab-storage-one-combined:/ /mnt/homelab \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=100G \
	    --vfs-cache-max-age=72h \
            --vfs-write-back=5s \
            --vfs-read-chunk-size=64M \
            --vfs-read-chunk-size-limit=2G \
            --vfs-read-ahead=128M \
            --buffer-size=32M \
            --allow-other \
            --log-level=INFO \
            --timeout=10m \
            --contimeout=60s \
            --transfers=4 \
	    --sftp-chunk-size=255k \
            --sftp-idle-timeout=5m \
            --dir-cache-time=1000h \
	    --checkers=4 \
	    --rc \
            --rc-addr=0.0.0.0:5572 \
            --rc-no-auth
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/homelab";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/homelab";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };

  systemd.services.backup-devil-srv = {
    description = "Backup Immich DB, Jellyfin, Navidrome to StorageBox";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "podman-immich-database.service" ];
    requires = [ "podman-immich-database.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "backup-devil-srv" ''
          set -euo pipefail

          # Immich DB — clean dump via pg_dump (consistent snapshot, safe during writes)
          # Restore:
          #   gunzip -c /tmp/immich-db.sql.gz | podman exec -i immich-database psql -U postgres immich
          ${pkgs.podman}/bin/podman exec immich-database pg_dump -U postgres immich \
            | ${pkgs.gzip}/bin/gzip > /tmp/immich-db.sql.gz

          # Sync to StorageBox
          ${pkgs.rclone}/bin/rclone copy /tmp/immich-db.sql.gz backups:/srv/immich/ \
            --config=${config.sops.secrets."rclone-main.conf".path}

          ${pkgs.rclone}/bin/rclone sync /srv/jellyfin backups:/srv/jellyfin/ \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --fast-list --transfers 4 --checkers 8

          ${pkgs.rclone}/bin/rclone sync /srv/navidrome backups:/srv/navidrome/ \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --fast-list --transfers 4 --checkers 8

          # Clean up
          rm -f /tmp/immich-db.sql.gz
        '';
      in "${script}";
    };
  };

  systemd.timers.backup-devil-srv = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}