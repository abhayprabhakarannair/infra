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

  systemd.services.rclone-media = {
    description = "Rclone mount for Hetzner Storage Box";
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = "${pkgs.coreutils}/bin/mkdir -p /mnt/media";

    serviceConfig = {
      TimeoutStartSec = "30";
      ExecStartPre = "${pkgs.coreutils}/bin/env";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount homelab-storage-one-media:/ /mnt/media \
          --config=${config.sops.secrets."rclone-conf".path} \
          --vfs-cache-mode=full \
          --vfs-cache-max-size=100G \
          --allow-other \
          --log-level=INFO
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u /mnt/media";
      Restart = "always";
      RestartSec = "10";
    };
  };
}
