{
  imports = [
    ../../modules/homelab-mounts.nix
    ../../modules/podman.nix
    ../../modules/services/jellyfin.nix
  ];
  my.services.podman.enable = true;
  my.services.homelabMounts = {
    enable = true;
    mediaCacheSize = "32G";
    mountB2 = false;
  };
  my.services.jellyfin.enable = true;
}
