{
  config,
  pkgs,
  inputs,
  ...
}: let
  proxyServices = {
    "home.iamabhay.fyi" = "old-devil:8123";

    "jellyfin.iamabhay.fyi" = "devil:8096";
    "music.iamabhay.fyi" = "devil:4533";
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
    "git.iamabhay.fyi" = "127.0.0.1:3333";
    "grafana.iamabhay.fyi" = "127.0.0.1:3000";
    "loki.iamabhay.fyi" = "127.0.0.1:3100";
    "prometheus.iamabhay.fyi" = "127.0.0.1:9090";
  };
in {
  sops.secrets."caddy/basic-auth-password" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
    owner = config.services.caddy.user;
    group = config.services.caddy.group;
    restartUnits = ["caddy.service"];
  };

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
