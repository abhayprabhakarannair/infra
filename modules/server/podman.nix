{
  virtualisation.containers.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    enable = true;
    # No repository workload consumes the Docker CLI shim or rootful API
    # socket. OCI containers use Podman directly through NixOS's module.
    dockerCompat = false;
    dockerSocket.enable = false;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };
}
