{ config, pkgs, inputs, ... }:

{
  sops.secrets."gluetun/env" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
    mode = "0440";
    uid = 1000;
    gid = 1000;
  };

  systemd.tmpfiles.rules = [
    "d /srv/prowlarr 0755 1000 1000 - -"
    "d /srv/sonarr 0755 1000 1000 - -"
    "d /srv/radarr 0755 1000 1000 - -"
    "d /srv/sabnzbd 0755 1000 1000 - -"
    "d /srv/downloads 0755 1000 1000 - -"
    "d /srv/whisparr 0755 1000 1000 - -"
    "d /srv/gluetun 0755 1000 1000 - -"
    "d /srv/qbittorrent 0755 1000 1000 - -"
    "d /srv/seerr 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers = {

    gluetun = {
      image = "qmcgaw/gluetun:latest";
      autoRemoveOnStop = false;
      ports = [ "8090:8090" ]; 
      volumes = [ 
        "/srv/gluetun:/gluetun" 
	"/srv/gluetun/wg0.conf:/gluetun/wireguard/wg0.conf"
      ];
      
      environmentFiles = [ config.sops.secrets."gluetun/env".path ];

      environment = {
        VPN_SERVICE_PROVIDER = "custom";
        VPN_TYPE = "wireguard";
        VPN_PORT_FORWARDING = "on";
        VPN_PORT_FORWARDING_PROVIDER = "private internet access";
	SERVER_NAME = "Server-11666-3a";
      };
      extraOptions = [
        "--restart=always"
        "--cap-add=NET_ADMIN"
        "--device=/dev/net/tun:/dev/net/tun"
      ];
    };

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
        "/mnt/homelab/media:/media"         
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
        "/mnt/homelab/media:/media"         
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
        "/mnt/homelab/media:/media"         
        "/srv/downloads:/downloads" 
      ];
      environment = { PUID = "1000"; PGID = "1000"; TZ = "Asia/Kolkata"; };
      extraOptions = [ "--restart=always" ];
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      autoRemoveOnStop = false;
      volumes = [ 
        "/srv/qbittorrent:/config"
        "/srv/downloads:/downloads" 
      ];
      environment = { 
        PUID = "1000"; 
        PGID = "1000"; 
        TZ = "Asia/Kolkata"; 
        WEBUI_PORT = "8090";
      };
      extraOptions = [ 
        "--restart=always"
        "--network=container:gluetun"
      ];
    };

    seerr = {
      image = "ghcr.io/seerr-team/seerr:latest";
      autoRemoveOnStop = false;
      ports = [ "5055:5055" ];
      volumes = [ "/srv/seerr:/app/config" ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
        LOG_LEVEL = "info";
      };
      extraOptions = [ "--restart=always" ];
    };

    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest";
      autoRemoveOnStop = false;
      ports = [ "8191:8191" ];
      environment = {
        LOG_LEVEL = "info";
      };
      extraOptions = [ "--restart=always" ];
    };
  };

  systemd.services.podman-gluetun = {
    before = [ "podman-qbittorrent.service" ];
  };

  systemd.services.podman-qbittorrent = {
    after = [ "podman-gluetun.service" ];
    requires = [ "podman-gluetun.service" ];
  };

  systemd.services.podman-whisparr = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
  };

  systemd.services.podman-sonarr = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
  };

  systemd.services.podman-radarr = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
  };
}
