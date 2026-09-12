{
  config,
  lib,
  unstablePkgs,
  ...
}: {
  options.my.services.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";

  config = lib.mkIf config.my.services.jellyfin.enable {
    services.jellyfin = {
      enable = true;
      package = unstablePkgs.jellyfin;
      dataDir = "/persistent/services/jellyfin";
    };

    # Seerr runs in the rootful Podman bridge namespace and reaches the
    # host-side Jellyfin listener through host.containers.internal. Permit
    # that bridge traffic without opening a new public listener.
    networking.firewall.interfaces.podman0.allowedTCPPorts = [8096];

    systemd.tmpfiles.rules = [
      "d /persistent/services/jellyfin 0750 jellyfin jellyfin -"
    ];

    systemd.services.jellyfin = {
      after = ["rclone-homelab-storage-one.service"];
      requires = ["rclone-homelab-storage-one.service"];
      unitConfig.RequiresMountsFor = [
        "/persistent/services/jellyfin"
        "/mnt/homelab-storage-one/media"
      ];
      serviceConfig = {
        PrivateUsers = lib.mkForce false;
        SupplementaryGroups = ["users" "render" "video"];
        ReadOnlyPaths = ["/mnt/homelab-storage-one/media"];
      };
    };
  };
}
