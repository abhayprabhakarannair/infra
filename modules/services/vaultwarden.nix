{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/vaultwarden 0750 root root -"
  ];

  virtualisation.oci-containers.containers.vaultwarden = {
    image = "vaultwarden/server:latest";
    autoRemoveOnStop = false;
    
    environment = {
      WEBSOCKET_ENABLED = "true";
      SIGNUPS_ALLOWED = "false"; 
    };
    
    ports = [
      "127.0.0.1:8222:80" 
    ];
    
    volumes = [
      "/srv/vaultwarden:/data"
    ];
    
    extraOptions = [
      "--restart=always"
      "--no-healthcheck"
    ];
  };
}
