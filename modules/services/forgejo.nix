{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/forgejo 0750 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.forgejo = {
    image = "codeberg.org/forgejo/forgejo:15";
    autoRemoveOnStop = false;
    
    environment = {
      USER_UID = "1000"; 
      USER_GID = "1000";
      FORGEJO__server__SSH_PORT = "2222"; 
      TZ = "Asia/Kolkata";
    };
    
    ports = [
      "127.0.0.1:3333:3000" 
      "2222:22"
    ];
    
    volumes = [
      "/srv/forgejo:/data"
      "/etc/localtime:/etc/localtime:ro"
    ];
    
    extraOptions = [
      "--no-healthcheck"
    ];
  };
}
