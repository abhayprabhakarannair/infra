
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
}
