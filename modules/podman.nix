{ config, lib, ... }:
{
  options.my.services.podman.enable = lib.mkEnableOption "Podman container runtime";

  config = lib.mkIf config.my.services.podman.enable {
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  };
}
