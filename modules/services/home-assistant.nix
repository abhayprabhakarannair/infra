{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/home-assistant 0755 root root -"
  ];

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable";
    autoRemoveOnStop = false;
    
    extraOptions = [
      "--network=host"
      "--restart=always"
    ];
    
    environment = {
      TZ = "Asia/Kolkata";
    };
    
    volumes = [
      "/srv/home-assistant:/config"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
