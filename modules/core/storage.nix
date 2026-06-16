{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [ "d /mnt/media 0750 1000 1000 -" ];

  sops.secrets."rclone-known-hosts" = {
    path = "/etc/rclone/known_hosts";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  sops.secrets."rclone-conf" = {
    path = "/etc/rclone/rclone.conf";
    owner = "root";
    group = "root";
    mode = "0400";
  };

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
            --vfs-read-chunk-size=16M \
            --vfs-read-chunk-size-limit=512M \
            --vfs-read-ahead=128M \
            --buffer-size=32M \
            --allow-other \
            --log-level=INFO
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/media";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/media";
        Restart = "always";
        RestartSec = "10";
      };
    };

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
            --vfs-read-chunk-size=16M \
            --vfs-read-chunk-size-limit=512M \
            --vfs-read-ahead=128M \
            --buffer-size=32M \
            --allow-other \
            --log-level=INFO
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/immich";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/immich";
        Restart = "always";
        RestartSec = "10";
      };
    };

    rclone-private = {
      description = "Rclone mount for Encrypted Private Data";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        ${pkgs.util-linux}/bin/umount -l /mnt/private || true
        ${pkgs.coreutils}/bin/mkdir -p /mnt/private
      '';

      serviceConfig = {
        TimeoutStartSec = "600";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'while ! ${pkgs.util-linux}/bin/mountpoint -q /mnt/private; do sleep 1; done'";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount homelab-storage-one-private:/ /mnt/private \
            --config=${config.sops.secrets."rclone-conf".path} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=5G \
            --vfs-read-chunk-size=16M \
            --vfs-read-chunk-size-limit=512M \
            --vfs-read-ahead=128M \
            --buffer-size=32M \
            --allow-other \
            --log-level=INFO
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/private";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l /mnt/private";
        Restart = "always";
        RestartSec = "10";
      };
    };

    rclone-shared = {
     description = "Rclone mount for Unncrypted Sharing Files";
     after = [ "network-online.target" ];
     wantedBy = [ "multi-user.target" ];

     preStart = "${pkgs.coreutils}/bin/mkdir -p /mnt/shared";

     serviceConfig = {
      TimeoutStartSec = "30";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount homelab-storage-one-shared:/ /mnt/shared \
          --config=${config.sops.secrets."rclone-conf".path} \
          --vfs-cache-mode=full \
          --vfs-cache-max-size=5G \
          --allow-other \
          --log-level=INFO
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/shared";
      Restart = "always";
      RestartSec = "10";
     };
   };


  };
}
