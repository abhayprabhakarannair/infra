{ config, pkgs, ... }:

{
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
  };
}
