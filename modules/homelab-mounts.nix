{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  rcloneConfig = config.sops.secrets."rclone-main.conf".path;
  cacheRoot = "/persistent/cache";

  mkMount = {
    remote,
    mountpoint,
    cacheName,
    cacheSize,
  }: let
    mountScript = pkgs.writeShellScript "rclone-mount-${cacheName}" ''
      exec ${pkgs.rclone}/bin/rclone mount ${remote}:/ ${mountpoint} \
        --config=${rcloneConfig} \
        --cache-dir=${cacheRoot}/${cacheName} \
        --vfs-cache-mode=full \
        --vfs-cache-max-size=${cacheSize} \
        --vfs-cache-max-age=72h \
        --vfs-write-back=5s \
        --vfs-read-chunk-size=64M \
        --vfs-read-chunk-size-limit=2G \
        --vfs-read-ahead=128M \
        --buffer-size=32M \
        --dir-cache-time=30s \
        --uid=$(${pkgs.coreutils}/bin/id -u abhay) \
        --gid=$(${pkgs.coreutils}/bin/id -g abhay) \
        --umask=002 \
        --allow-other \
        --default-permissions
    '';
  in {
    description = "Rclone mount for ${remote}";
    wants = ["network-online.target"];
    after = ["network-online.target" "persistent.mount"];
    wantedBy = ["multi-user.target"];
    unitConfig = {
      ConditionPathExists = rcloneConfig;
      RequiresMountsFor = [cacheRoot mountpoint];
    };
    restartTriggers = [
      config.sops.secrets."rclone-main.conf".sopsFileHash
      config.sops.secrets."rclone-known-hosts".sopsFileHash
    ];
    preStart = ''
      ${pkgs.util-linux}/bin/umount -l ${mountpoint} || true
      ${pkgs.coreutils}/bin/mkdir -p ${mountpoint} ${cacheRoot}/${cacheName}
    '';
    serviceConfig = {
      Type = "notify";
      TimeoutStartSec = "10min";
      ExecStart = mountScript;
      ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountpoint}";
      ExecStopPost = "-${pkgs.util-linux}/bin/umount -l ${mountpoint}";
      Restart = "always";
      RestartSec = 10;
    };
  };
in {
  options.my.services.homelabMounts = {
    enable = lib.mkEnableOption "homelab storage rclone mounts";
    mediaCacheSize = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "Maximum local VFS cache size for the authoritative homelab mount.";
    };
    mountB2 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mount the B2 replica in addition to the authoritative homelab storage.";
    };
  };

  config = lib.mkIf config.my.services.homelabMounts.enable {
    sops.secrets."rclone-main.conf" = {
      sopsFile = "${inputs.self}/secrets/rclone/rclone-main.conf";
      format = "binary";
      owner = "abhay";
      group = "users";
      mode = "0400";
    };
    sops.secrets."rclone-known-hosts" = {
      sopsFile = "${inputs.self}/secrets/rclone/secrets.yaml";
      key = "known-hosts";
      path = "/etc/rclone/known_hosts";
      owner = "root";
      group = "users";
      mode = "0440";
    };

    environment.systemPackages = [
      pkgs.rclone
      pkgs.rsync
    ];

    systemd.tmpfiles.rules =
      [
        "d /mnt/homelab-storage-one 0750 abhay users -"
        "d ${cacheRoot} 0750 root root -"
      ]
      ++ lib.optional config.my.services.homelabMounts.mountB2 "d /mnt/b2 0750 abhay users -";

    systemd.services =
      {
        rclone-homelab-storage-one = mkMount {
          remote = "homelab-storage-one-combined";
          mountpoint = "/mnt/homelab-storage-one";
          cacheName = "rclone-homelab-storage-one";
          cacheSize = config.my.services.homelabMounts.mediaCacheSize;
        };
      }
      // lib.optionalAttrs config.my.services.homelabMounts.mountB2 {
        rclone-b2-combined = mkMount {
          remote = "b2-combined";
          mountpoint = "/mnt/b2";
          cacheName = "rclone-b2-storage";
          cacheSize = "1G";
        };
      };
  };
}
