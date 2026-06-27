{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/navidrome 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.navidrome = {
    image = "deluan/navidrome:latest";
    autoRemoveOnStop = false;
    
    ports = [
      "4533:4533"
    ];
    
    environment = {
      ND_SCANSCHEDULE = "1h";
      ND_LOGLEVEL = "info";
      ND_BASEURL = ""; 
    };
    
    volumes = [
      "/srv/navidrome:/data"
      "/mnt/homelab/media/music:/music:ro"
    ];
    
    extraOptions = [
      "--restart=always"
      "--no-healthcheck"
    ];
  };

  systemd.services.podman-navidrome = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
  };
}
