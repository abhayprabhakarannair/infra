{
  ...
}:
{
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };
}
