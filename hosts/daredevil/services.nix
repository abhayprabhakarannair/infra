{
  # Workload inventory for Daredevil:
  # - Podman runtime
  # - Homelab StorageBox decrypted view
  # - Backblaze B2 decrypted replica view
  imports = [
    ../../modules/podman.nix
    ../../modules/homelab-mounts.nix
  ];

  my.services = {
    podman.enable = true;
    homelabMounts.enable = true;
  };
}
