{ config, pkgs, ... }:

let
  proxyServices = {
    "jellyfin.iamabhay.fyi"    = "devil:8096";
    "music.iamabhay.fyi"       = "devil:4533";
    "stash.iamabhay.fyi"       = "devil:9999";
    "sonarr.iamabhay.fyi"      = "devil:8989";
    "radarr.iamabhay.fyi"      = "devil:7878";
    "sabnzbd.iamabhay.fyi"     = "devil:8080";
    "prowlarr.iamabhay.fyi"    = "devil:9696";
    "whisparr.iamabhay.fyi"    = "devil:6969";
    "qbittorrent.iamabhay.fyi" = "devil:8090";
    "seerr.iamabhay.fyi"       = "devil:5055";
    "photos.iamabhay.fyi"      = "devil:2283";
    
    "vault.iamabhay.fyi"       = "127.0.0.1:8222";
    "grafana.iamabhay.fyi"     = "127.0.0.1:3000";
    "loki.iamabhay.fyi"        = "127.0.0.1:3100";
    "prometheus.iamabhay.fyi"  = "127.0.0.1:9090";
  };
in
{
  sops.secrets."caddy-basic-auth" = {
    owner = config.services.caddy.user;
    group = config.services.caddy.group;
    restartUnits = [ "caddy.service" ]; 
  };

  services.caddy = {
    enable = true;

    virtualHosts = builtins.mapAttrs (domain: backend: {
      extraConfig = ''
        reverse_proxy ${backend}
        
        log {
            format json
        }
      '';
    }) proxyServices;
  };
}
