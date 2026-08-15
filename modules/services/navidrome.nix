{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/navidrome 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.navidrome = {
    image = "deluan/navidrome:latest@sha256:38246ebb80d6f7e2724eecab4acafa7b14ec66ae800b2454aa6da4c19f80a9ce";
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
