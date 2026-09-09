{
  imports = [../../modules/podman.nix ../../modules/homelab-mounts.nix];
  my.services.podman.enable = true;
  my.services.homelabMounts = {
    enable = true;
    mediaCacheSize = "32G";
    mountB2 = false;
  };
}
