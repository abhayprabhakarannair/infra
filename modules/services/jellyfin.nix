{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/jellyfin 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.jellyfin = {
    image = "jellyfin/jellyfin:latest";
    autoRemoveOnStop = false;
    
    ports = [
      "8096:8096"
    ];
    
    volumes = [
      "/srv/jellyfin:/config"
      "/mnt/media:/media" 
    ];
    
    extraOptions = [
      "--restart=always"
      "--device=/dev/dri:/dev/dri" 
      "--no-healthcheck"
    ];
  };

  systemd.services.podman-jellyfin = {
    after = [ "rclone-media.service" ];
    requires = [ "rclone-media.service" ];
  };
}
