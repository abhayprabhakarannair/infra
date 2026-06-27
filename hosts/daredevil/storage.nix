{conifg, pkgs, inputs, ...}:

{
  imports = [
   "${inputs.self}/modules/storage/main.nix"
   "${inputs.self}/modules/syncthing"
  ];

  systemd.tmpfiles.rules = [ 
    "d /mnt/private 0750 1000 1000 -"
    "d /mnt/media 0750 1000 1000 -"
  ];

  systemd.services = {
   rclone-private = {
      description = "Rclone mount for Encrypted Private Files";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/private || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/private
      '';

      serviceConfig = {
        Type = "notify";
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/private; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount private:/ /mnt/private \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --vfs-cache-mode=writes \
            --allow-other
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/private";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/private";
        Restart = "always";
        RestartSec = "10";
      };
    };

   # Only run when media is required, else saves battery
   rclone-media = {
      description = "Rclone mount for Encrypted Media";
      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/media || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/media
      '';

      serviceConfig = {
        Type = "notify";
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/media; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount media:/ /mnt/media \
            --config=${config.sops.secrets."rclone-main.conf".path} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=10G \
	    --vfs-cache-max-age=72h \
            --vfs-read-chunk-size=32M \
            --vfs-read-chunk-size-limit=2G \
            --vfs-read-ahead=128M \
            --buffer-size=32M \
            --allow-other \
            --log-level=INFO \
            --timeout=10m \
            --contimeout=60s \
	    --sftp-chunk-size=255k \
            --sftp-idle-timeout=5m
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/media";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/media";
      };
    };
  };
}
