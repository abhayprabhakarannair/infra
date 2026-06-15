{ config, pkgs, ... }:

{
  sops.secrets."caddy-basic-auth" = {
    owner = config.services.caddy.user;
    group = config.services.caddy.group;
    restartUnits = [ "caddy.service" ]; 
  };

  services.caddy = {
    enable = true;

    virtualHosts."vault.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:8222
      '';
    };

    virtualHosts."jellyfin.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:8096
      '';
    };

    virtualHosts."music.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:4533
      '';
    };

   
    virtualHosts."stash.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:9999
      '';
    };


    virtualHosts."sonarr.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:8989
      '';
    };


    virtualHosts."radarr.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:7878
      '';
    };


    virtualHosts."sabnzbd.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:8080
      '';
    };


    virtualHosts."prowlarr.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:9696
      '';
    };

    virtualHosts."whisparr.iamabhay.fyi" = {
      extraConfig = ''
        reverse_proxy devil:6969
      '';
    };

  };
}
