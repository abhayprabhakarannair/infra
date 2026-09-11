{
  imports = [
    ../../modules/homelab-mounts.nix
    ../../modules/podman.nix
    ../../modules/services/arr.nix
    ../../modules/services/jellyfin.nix
  ];
  my.services.podman.enable = true;
  my.services.homelabMounts = {
    enable = true;
    mediaCacheSize = "32G";
    mountB2 = false;
  };
  # gluetun/env is read from the encrypted service-secrets file.
  my.services.arr.enable = true;
  # Enable only after arr/prowlarr-state and arr/prowlarr/env are added there.
  my.services.arr.reconcile.enable = false;
  my.services.jellyfin.enable = true;
}
