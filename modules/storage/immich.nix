{ config, pkgs, ... }:

{

  systemd.services = {

    rclone-immich = {
      description = "Rclone mount for Encrypted Immich Data";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/immich || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/immich
      '';

      serviceConfig = {
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/immich; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount homelab-storage-one-immich:/ /mnt/immich \
            --config=${config.sops.secrets."rclone-conf".path} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=40G \
	    --vfs-cache-max-age=72h \
            --vfs-read-chunk-size=32M \
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
            --dir-cache-time=48h \
	    --checkers=4 \
	    --rc \
            --rc-addr=0.0.0.0:5573 \
            --rc-no-auth
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/immich";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/immich";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}
