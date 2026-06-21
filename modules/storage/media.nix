{ config, pkgs, ... }:

{
  systemd.services = {

   rclone-media = {
      description = "Rclone mount for Encrypted Media";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/media || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/media
      '';

      serviceConfig = {
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/media; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount homelab-storage-one-media:/ /mnt/media \
            --config=${config.sops.secrets."rclone-conf".path} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=100G \
	    --vfs-cache-max-age=72h \
            --vfs-write-back=5s \
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
            --dir-cache-time=10m \
	    --checkers=4 \
	    --rc \
            --rc-addr=0.0.0.0:5572 \
            --rc-no-auth
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/media";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/media";
        Restart = "always";
        RestartSec = "10";
      };
    };
  };
}
