{ unstablePkgs, ... }:
{
  services.jellyfin = {
    enable = true;
    package = unstablePkgs.jellyfin;
    dataDir = "/persistent/services/jellyfin";
  };

  systemd.tmpfiles.rules = [
    "d /persistent/services/jellyfin 0750 jellyfin jellyfin -"
  ];

  systemd.services.jellyfin = {
    after = [ "rclone-homelab-storage-one.service" ];
    requires = [ "rclone-homelab-storage-one.service" ];
    unitConfig.RequiresMountsFor = [
      "/persistent/services/jellyfin"
      "/mnt/homelab-storage-one/media"
    ];
    serviceConfig.SupplementaryGroups = [ "users" "render" "video" ];
  };
}
