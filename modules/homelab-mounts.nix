{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  rcloneConfig = config.sops.secrets."rclone-main.conf".path;

  mkMount = {
    remote,
    mountpoint,
    cacheName,
    cacheSize,
  }:
    {
      description = "Rclone mount for ${remote}";
      wants = ["network-online.target"];
      requires = ["sops-install-secrets.service"];
      after = ["network-online.target" "sops-install-secrets.service"];
      wantedBy = ["multi-user.target"];
      preStart = ''
        ${pkgs.util-linux}/bin/umount -l ${mountpoint} || true
        ${pkgs.coreutils}/bin/mkdir -p ${mountpoint}
      '';
      serviceConfig = {
        Type = "notify";
        TimeoutStartSec = "10min";
        ExecStart = ''
          ${pkgs.rclone}/bin/rclone mount ${remote}:/ ${mountpoint} \
            --config=${rcloneConfig} \
            --cache-dir=/var/cache/${cacheName} \
            --vfs-cache-mode=full \
            --vfs-cache-max-size=${cacheSize} \
            --vfs-cache-max-age=72h \
            --vfs-write-back=5s \
            --dir-cache-time=30s \
            --allow-other
        '';
        ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountpoint}";
        ExecStopPost = "-${pkgs.util-linux}/bin/umount -l ${mountpoint}";
        Restart = "always";
        RestartSec = 10;
      };
    };
in
{
  options.my.services.homelabMounts.enable = lib.mkEnableOption "homelab storage rclone mounts";

  config = lib.mkIf config.my.services.homelabMounts.enable {
    sops.secrets."rclone-main.conf" = {
      sopsFile = "${inputs.self}/secrets/rclone/rclone-main.conf";
      format = "binary";
      owner = "abhay";
      group = "users";
      mode = "0400";
      restartUnits = [
        "rclone-homelab-storage-one.service"
        "rclone-b2-combined.service"
      ];
    };
    sops.secrets."rclone-known-hosts" = {
      sopsFile = "${inputs.self}/secrets/rclone/secrets.yaml";
      key = "known-hosts";
      path = "/etc/rclone/known_hosts";
      owner = "root";
      group = "users";
      mode = "0440";
      restartUnits = [
        "rclone-homelab-storage-one.service"
        "rclone-b2-combined.service"
      ];
    };

    environment.systemPackages = [ pkgs.rclone ];

    systemd.tmpfiles.rules = [
      "d /mnt/homelab-storage-one 0750 abhay users -"
      "d /mnt/b2 0750 abhay users -"
    ];

    systemd.services = {
      rclone-homelab-storage-one = mkMount {
        remote = "homelab-storage-one-combined";
        mountpoint = "/mnt/homelab-storage-one";
        cacheName = "rclone-homelab-storage-one";
        cacheSize = "4G";
      };
      rclone-b2-combined = mkMount {
        remote = "b2-combined";
        mountpoint = "/mnt/b2";
        cacheName = "rclone-b2-storage";
        cacheSize = "1G";
      };
    };
  };
}
