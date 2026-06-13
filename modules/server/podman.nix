{
  virtualisation.containers.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };
}
