{...}: let
  proxyServices = {
    "home.iamabhay.fyi" = "old-devil:8123";

    "jellyfin.iamabhay.fyi" = "devil:8096";
    "stash.iamabhay.fyi" = "devil:9999";
    "sonarr.iamabhay.fyi" = "devil:8989";
    "radarr.iamabhay.fyi" = "devil:7878";
    "sabnzbd.iamabhay.fyi" = "devil:8080";
    "prowlarr.iamabhay.fyi" = "devil:9696";
    "whisparr.iamabhay.fyi" = "devil:6969";
    "qbittorrent.iamabhay.fyi" = "devil:8090";
    "seerr.iamabhay.fyi" = "devil:5055";
    "photos.iamabhay.fyi" = "devil:2283";

    "vault.iamabhay.fyi" = "127.0.0.1:8222";
  };
in {
  # The proxied applications own authentication (Jellyfin, the Arr stack,
  # Immich, Vaultwarden, and Home Assistant). Do not declare an unused Caddy
  # password secret that suggests the proxy itself is protecting these hosts.
  services.caddy = {
    enable = true;

    virtualHosts =
      builtins.mapAttrs (domain: backend: {
        # Disable the module's default per-vhost log block; we define our own
        # below (with rotation) inside extraConfig instead.
        logFormat = null;
        extraConfig = ''
          reverse_proxy ${backend}

          log {
              format json
              output file /var/log/caddy/access-${domain}.log {
                  roll_size 10mb
                  roll_keep 5
                  roll_keep_for 168h
              }
          }
        '';
      })
      proxyServices;
  };
}
