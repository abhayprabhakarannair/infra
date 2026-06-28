{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/open-webui 0755 root root -"
  ];

  virtualisation.oci-containers = {
    containers."open-webui" = {
      image = "ghcr.io/open-webui/open-webui:main";
      ports = [ "8448:8080" ];
      
      volumes = [
        "/srv/open-webui:/app/backend/data"
      ];
      
      environment = {
        WEBUI_AUTH = "True";
      };
      
    };
  };
}
