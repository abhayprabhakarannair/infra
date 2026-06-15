{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/prowlarr 0755 1000 1000 - -"
    "d /srv/sonarr 0755 1000 1000 - -"
    "d /srv/radarr 0755 1000 1000 - -"
    "d /srv/sabnzbd 0755 1000 1000 - -"
    "d /srv/downloads 0755 1000 1000 - -"
    "d /srv/whisparr 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers = {
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      autoRemoveOnStop = false;
      ports = [ "9696:9696" ]; 
      volumes = [ "/srv/prowlarr:/config" ];
      environment = { 
        PUID = "1000"; 
        PGID = "1000"; 
        TZ = "Asia/Kolkata"; 
      };
      extraOptions = [ "--restart=always" ];
    };

    sabnzbd = {
      image = "lscr.io/linuxserver/sabnzbd:latest";
      autoRemoveOnStop = false;
      ports = [ "8080:8080" ];
      volumes = [ 
        "/srv/sabnzbd:/config"
        "/srv/downloads:/downloads" 
      ];
      environment = { PUID = "1000"; PGID = "1000"; TZ = "Asia/Kolkata"; };
      extraOptions = [ "--restart=always" ];
    };

    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      autoRemoveOnStop = false;
      ports = [ "8989:8989" ];
      volumes = [ 
        "/srv/sonarr:/config"
        "/mnt/media:/media"         
        "/srv/downloads:/downloads" 
      ];
      environment = { PUID = "1000"; PGID = "1000"; TZ = "Asia/Kolkata"; };
      extraOptions = [ "--restart=always" ];
    };

    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      autoRemoveOnStop = false;
      ports = [ "7878:7878" ];
      volumes = [ 
        "/srv/radarr:/config"
        "/mnt/media:/media"         
        "/srv/downloads:/downloads" 
      ];
      environment = { PUID = "1000"; PGID = "1000"; TZ = "Asia/Kolkata"; };
      extraOptions = [ "--restart=always" ];
    };

    whisparr = {
      image = "ghcr.io/hotio/whisparr:v3";
      autoRemoveOnStop = false;
      ports = [ "6969:6969" ];
      volumes = [ 
        "/srv/whisparr:/config"
        "/mnt/media:/media"         
        "/srv/downloads:/downloads" 
      ];
      environment = { PUID = "1000"; PGID = "1000"; TZ = "Asia/Kolkata"; };
      extraOptions = [ "--restart=always" ];
    };
  };

  systemd.services.podman-whisparr = {
    after = [ "rclone-media.service" ];
    requires = [ "rclone-media.service" ];
  };

  systemd.services.podman-sonarr = {
    after = [ "rclone-media.service" ];
    requires = [ "rclone-media.service" ];
  };

  systemd.services.podman-radarr = {
    after = [ "rclone-media.service" ];
    requires = [ "rclone-media.service" ];
  };
}
