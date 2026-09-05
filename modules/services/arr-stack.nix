{
  config,
  pkgs,
  inputs,
  ...
}: let
  # These services write state only to their declared bind mounts. Keep a
  # writable /tmp and /run for s6-based images while making the image root
  # immutable and bounding process count and memory.
  hardened = [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
    "--read-only"
    "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
    "--tmpfs=/run:rw,nosuid,nodev"
    "--pids-limit=512"
    "--memory=1g"
    "--cpus=2"
  ];
in {
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
      image = "qmcgaw/gluetun:latest@sha256:901e9585ac960658cb1e7f93dd0b145f2ca210cd47a8b0f3390ae17b4b51b1b3";
      autoRemoveOnStop = false;
      ports = ["8090:8090"];
      volumes = [
        "/srv/gluetun:/gluetun"
      ];

      environmentFiles = [config.sops.secrets."gluetun/env".path];

      environment = {
        VPN_SERVICE_PROVIDER = "private internet access";
        VPN_TYPE = "openvpn";
        SERVER_REGIONS = "Netherlands";
        VPN_PORT_FORWARDING = "on";
        OPENVPN_MSSFIX = "1280";
        OPENVPN_CUSTOM_OPTIONS = "--tun-mtu 1300 --mssfix 1260";
      };
      extraOptions = [
        "--restart=always"
        # Gluetun is the deliberate privilege boundary for the VPN network
        # namespace. These are the only capabilities it needs. Keep its root
        # filesystem and privilege transitions writable because it must
        # initialize tunnel/routing state inside the container.
        "--cap-drop=ALL"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
        "--device=/dev/net/tun:/dev/net/tun"
        "--pids-limit=512"
        "--memory=1g"
        "--cpus=2"
      ];
    };

    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest@sha256:fc10055b0fbda44b7d75a68ba9a336e378cd8dcec49809f24e8a1cad7bb97b49";
      autoRemoveOnStop = false;
      ports = ["9696:9696"];
      volumes = ["/srv/prowlarr:/config"];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    sabnzbd = {
      image = "lscr.io/linuxserver/sabnzbd:latest@sha256:341b91c31403e46aff0ac640d9889092649f168a5f1edb8bb26d61abee62643a";
      autoRemoveOnStop = false;
      ports = ["8080:8080"];
      volumes = [
        "/srv/sabnzbd:/config"
        "/srv/downloads:/downloads"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest@sha256:729b8f38d99b3af0c02bbb778f2184ed426676ecaad1fa87d12fb5347e36892a";
      autoRemoveOnStop = false;
      ports = ["8989:8989"];
      volumes = [
        "/srv/sonarr:/config"
        "/mnt/homelab/media:/media"
        "/srv/downloads:/downloads"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    radarr = {
      image = "lscr.io/linuxserver/radarr:latest@sha256:263be1036419fcb38fc1cf76be90db8db4b0dc49fd492617b17cc58e9e0bf1b5";
      autoRemoveOnStop = false;
      ports = ["7878:7878"];
      volumes = [
        "/srv/radarr:/config"
        "/mnt/homelab/media:/media"
        "/srv/downloads:/downloads"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    whisparr = {
      image = "ghcr.io/hotio/whisparr:v3@sha256:6e2e7072a718fc850686ead3695971c1afc3e43fd7d46d95fd653d12e86e5584";
      autoRemoveOnStop = false;
      ports = ["6969:6969"];
      volumes = [
        "/srv/whisparr:/config"
        "/mnt/homelab/media:/media"
        "/srv/downloads:/downloads"
      ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    qbittorrent = {
      image = "lscr.io/linuxserver/qbittorrent:latest@sha256:fdc1655ae220e16c2784efc3d8fc8738c17cad0a470c8a022767339c33aaaaac";
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
        # qBittorrent shares Gluetun's network namespace and needs a larger
        # memory allowance for torrent metadata and active transfers.
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--read-only"
        "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
        "--tmpfs=/run:rw,nosuid,nodev"
        "--pids-limit=1024"
        "--memory=2g"
        "--cpus=4"
        "--restart=always"
        "--network=container:gluetun"
      ];
    };

    seerr = {
      image = "ghcr.io/seerr-team/seerr:latest@sha256:b21cf91bb7a10d70446e104e7b7b9c9c386aa22beeac535a3271cbfc5843d142";
      autoRemoveOnStop = false;
      ports = ["5055:5055"];
      volumes = ["/srv/seerr:/app/config"];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = "Asia/Kolkata";
        LOG_LEVEL = "info";
      };
      extraOptions = hardened ++ ["--restart=always"];
    };

    flaresolverr = {
      image = "ghcr.io/flaresolverr/flaresolverr:latest@sha256:258523d25e4e07028c3a206f0e03ae807b26a50a201dd320f09a18464ecf86fa";
      autoRemoveOnStop = false;
      ports = ["8191:8191"];
      environment = {
        LOG_LEVEL = "info";
      };
      # Flaresolverr has no declared writable state. Its temporary files are
      # confined to the tmpfs supplied by `hardened`.
      extraOptions = hardened ++ ["--restart=always"];
    };
  };

  systemd.services.podman-gluetun = {
    before = ["podman-qbittorrent.service"];
  };

  systemd.services.podman-qbittorrent = {
    after = ["podman-gluetun.service"];
    requires = ["podman-gluetun.service"];
  };

  systemd.services.podman-whisparr = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };

  systemd.services.podman-sonarr = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };

  systemd.services.podman-radarr = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };
}
