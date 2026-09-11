{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.services.arr;
  serviceSecretsFile = "${inputs.self}/secrets/service-secrets.yaml";

  containerNames = [
    "gluetun"
    "qbittorrent"
    "prowlarr"
    "sonarr"
    "radarr"
    "seerr"
    "whisparr"
  ];
  containerServiceNames = map (name: "podman-${name}") containerNames;
  containerUnits = map (name: "${name}.service") containerServiceNames;
  mediaMountRoot = builtins.dirOf cfg.mediaRoot;

  appEnvironment = {
    PUID = toString cfg.uid;
    PGID = toString cfg.gid;
    TZ = cfg.timeZone;
  };

  hardened = {
    pidsLimit,
    memory,
    cpus,
  }: [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
    "--pids-limit=${toString pidsLimit}"
    "--memory=${memory}"
    "--cpus=${toString cpus}"
  ];

  prowlarrReconcileScript = pkgs.writeShellApplication {
    name = "arr-prowlarr-reconcile";
    runtimeInputs = with pkgs; [bash curl coreutils jq];
    text = ''
      exec ${./../../scripts/arr/prowlarr-reconcile.sh} "$@"
    '';
  };

  qbittorrentRecoveryScript = pkgs.writeShellScript "arr-restart-qbittorrent-after-gluetun" ''
    if ${pkgs.systemd}/bin/systemctl is-active --quiet podman-gluetun.service; then
      ${pkgs.systemd}/bin/systemctl --no-block start podman-qbittorrent.service
    fi
  '';

  mediaService = {
    after = ["rclone-homelab-storage-one.service"];
    requires = ["rclone-homelab-storage-one.service"];
    bindsTo = ["rclone-homelab-storage-one.service"];
    partOf = ["arr-stack.target"];
    unitConfig = {
      # rclone is a service rather than a fileSystems entry, so retain both the
      # explicit service dependency and the path-level mount requirement.
      RequiresMountsFor = [
        cfg.configRoot
        cfg.stagingRoot
        cfg.mediaRoot
      ];
      ConditionPathIsMountPoint = mediaMountRoot;
      ConditionPathIsDirectory = cfg.mediaRoot;
    };
    serviceConfig.RestartSec = 10;
  };
in {
  options.my.services.arr = {
    enable = lib.mkEnableOption "the Podman-based ARR media automation stack";

    configRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persistent/services/arr";
      description = "Persistent root for ARR application configuration and databases.";
    };

    stagingRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persistent/work/arr";
      description = "Local persistent root for downloads and import staging.";
    };

    mediaRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/homelab-storage-one/media";
      description = "Authoritative media library mounted from homelab storage.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID passed to images that support PUID.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "GID passed to images that support PGID.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Asia/Kolkata";
      description = "Timezone passed to ARR containers.";
    };

    reconcile = {
      enable = lib.mkEnableOption "declarative Prowlarr reconciliation";

      stateSecretName = lib.mkOption {
        type = lib.types.str;
        default = "arr/prowlarr-state";
        description = "SOPS secret containing the declarative Prowlarr JSON state.";
      };

      environmentSecretName = lib.mkOption {
        type = lib.types.str;
        default = "arr/prowlarr/env";
        description = ''
          SOPS secret containing KEY=VALUE lines for PROWLARR_API_KEY and any
          ''${ENV:NAME} placeholders used by the Prowlarr state.
        '';
      };
    };

    gluetun = {
      envSecretName = lib.mkOption {
        type = lib.types.str;
        default = "gluetun/env";
        description = ''
          Name of the SOPS secret containing Gluetun environment variables.
          Add this key to the configured SOPS default file before activation.
        '';
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          VPN_SERVICE_PROVIDER = "private internet access";
          VPN_TYPE = "openvpn";
          SERVER_REGIONS = "Netherlands";
          VPN_PORT_FORWARDING = "on";
          OPENVPN_MSSFIX = "1280";
          OPENVPN_CUSTOM_OPTIONS = "--tun-mtu 1300 --mssfix 1260";
        };
        description = "Non-secret Gluetun settings; credentials belong in envSecretName.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.podman.enable;
        message = "my.services.arr requires my.services.podman.enable = true";
      }
      {
        assertion = config.users.users.abhay.uid == cfg.uid;
        message = "my.services.arr.uid must match users.users.abhay.uid";
      }
      {
        assertion = config.users.groups.users.gid == cfg.gid;
        message = "my.services.arr.gid must match users.groups.users.gid";
      }
    ];

    # ARR credentials live in the encrypted service-secrets file. Keep service
    # credentials separate from machine identity and user secrets.
    sops.secrets = lib.mkMerge [
      {
        ${cfg.gluetun.envSecretName} = {
          sopsFile = serviceSecretsFile;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = ["podman-gluetun.service"];
        };
      }
      (lib.mkIf cfg.reconcile.enable {
        ${cfg.reconcile.stateSecretName} = {
          sopsFile = serviceSecretsFile;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = ["arr-prowlarr-reconcile.service"];
        };
        ${cfg.reconcile.environmentSecretName} = {
          sopsFile = serviceSecretsFile;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = ["arr-prowlarr-reconcile.service"];
        };
      })
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.configRoot} 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/gluetun 0700 root root -"
      "d ${cfg.configRoot}/qbittorrent 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/prowlarr 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/sonarr 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/radarr 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/seerr 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.configRoot}/whisparr 0750 ${toString cfg.uid} ${toString cfg.gid} -"
      "d ${cfg.stagingRoot} 0750 ${toString cfg.uid} ${toString cfg.gid} -"
    ];

    virtualisation.oci-containers = {
      backend = "podman";
      containers = {
        gluetun = {
          image = "qmcgaw/gluetun:latest@sha256:901e9585ac960658cb1e7f93dd0b145f2ca210cd47a8b0f3390ae17b4b51b1b3";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:8090:8090"];
          user = "0:0";
          volumes = ["${cfg.configRoot}/gluetun:/gluetun"];
          environment = cfg.gluetun.environment;
          environmentFiles = [config.sops.secrets.${cfg.gluetun.envSecretName}.path];
          extraOptions =
            hardened {
              pidsLimit = 512;
              memory = "1g";
              cpus = 2;
            }
            ++ [
              "--cap-add=NET_ADMIN"
              "--cap-add=NET_RAW"
              "--device=/dev/net/tun:/dev/net/tun"
            ];
        };

        # This container has no host ports or normal Podman network. Its only
        # network namespace is Gluetun's, so it cannot run outside the VPN.
        qbittorrent = {
          image = "lscr.io/linuxserver/qbittorrent:latest@sha256:fdc1655ae220e16c2784efc3d8fc8738c17cad0a470c8a022767339c33aaaaac";
          autoStart = false;
          autoRemoveOnStop = true;
          dependsOn = ["gluetun"];
          volumes = [
            "${cfg.configRoot}/qbittorrent:/config"
            "${cfg.stagingRoot}:/downloads"
          ];
          environment = appEnvironment // {WEBUI_PORT = "8090";};
          extraOptions =
            hardened {
              pidsLimit = 1024;
              memory = "2g";
              cpus = 4;
            }
            ++ ["--network=container:gluetun"];
        };

        prowlarr = {
          image = "lscr.io/linuxserver/prowlarr:latest@sha256:fc10055b0fbda44b7d75a68ba9a336e378cd8dcec49809f24e8a1cad7bb97b49";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:9696:9696"];
          volumes = ["${cfg.configRoot}/prowlarr:/config"];
          environment = appEnvironment;
          extraOptions = hardened {
            pidsLimit = 512;
            memory = "1g";
            cpus = 2;
          };
        };

        sonarr = {
          image = "lscr.io/linuxserver/sonarr:latest@sha256:729b8f38d99b3af0c02bbb778f2184ed426676ecaad1fa87d12fb5347e36892a";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:8989:8989"];
          volumes = [
            "${cfg.configRoot}/sonarr:/config"
            "${cfg.stagingRoot}:/downloads"
            "${cfg.mediaRoot}:/media"
          ];
          environment = appEnvironment;
          extraOptions = hardened {
            pidsLimit = 512;
            memory = "1g";
            cpus = 2;
          };
        };

        radarr = {
          image = "lscr.io/linuxserver/radarr:latest@sha256:263be1036419fcb38fc1cf76be90db8db4b0dc49fd492617b17cc58e9e0bf1b5";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:7878:7878"];
          volumes = [
            "${cfg.configRoot}/radarr:/config"
            "${cfg.stagingRoot}:/downloads"
            "${cfg.mediaRoot}:/media"
          ];
          environment = appEnvironment;
          extraOptions = hardened {
            pidsLimit = 512;
            memory = "1g";
            cpus = 2;
          };
        };

        seerr = {
          image = "ghcr.io/seerr-team/seerr:latest@sha256:b21cf91bb7a10d70446e104e7b7b9c9c386aa22beeac535a3271cbfc5843d142";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:5055:5055"];
          volumes = ["${cfg.configRoot}/seerr:/app/config"];
          environment = appEnvironment // {LOG_LEVEL = "info";};
          extraOptions = hardened {
            pidsLimit = 512;
            memory = "1g";
            cpus = 2;
          };
        };

        whisparr = {
          image = "ghcr.io/hotio/whisparr:v3@sha256:6e2e7072a718fc850686ead3695971c1afc3e43fd7d46d95fd653d12e86e5584";
          autoStart = false;
          autoRemoveOnStop = true;
          ports = ["127.0.0.1:6969:6969"];
          volumes = [
            "${cfg.configRoot}/whisparr:/config"
            "${cfg.stagingRoot}:/downloads"
            "${cfg.mediaRoot}:/media"
          ];
          environment = appEnvironment;
          extraOptions = hardened {
            pidsLimit = 512;
            memory = "1g";
            cpus = 2;
          };
        };
      };
    };

    systemd.targets.arr-stack = {
      description = "ARR media automation stack";
      wantedBy = ["multi-user.target"];
      after = ["rclone-homelab-storage-one.service"];
      requires = containerUnits;
      unitConfig = {
        RequiresMountsFor = [
          cfg.configRoot
          cfg.stagingRoot
          cfg.mediaRoot
        ];
        ConditionPathIsMountPoint = mediaMountRoot;
        ConditionPathIsDirectory = cfg.mediaRoot;
      };
    };

    systemd.services = lib.mkMerge [
      (lib.genAttrs containerServiceNames (_: mediaService))
      {
        podman-gluetun.before = ["podman-qbittorrent.service"];
        podman-qbittorrent = {
          # dependsOn above supplies After= and Requires=; BindsTo= additionally
          # stops qBittorrent whenever its VPN namespace disappears.
          bindsTo = ["podman-gluetun.service"];
        };
        rclone-homelab-storage-one.serviceConfig.ExecStartPost = lib.mkAfter [
          "-${pkgs.systemd}/bin/systemctl --no-block start arr-stack.target"
        ];
        podman-gluetun.serviceConfig.ExecStartPost = lib.mkAfter [
          qbittorrentRecoveryScript
        ];
      }
      (lib.mkIf cfg.reconcile.enable {
        arr-prowlarr-reconcile = {
          description = "Reconcile declarative Prowlarr state";
          wantedBy = ["arr-stack.target"];
          after = [
            "podman-prowlarr.service"
            "podman-qbittorrent.service"
            "podman-sonarr.service"
            "podman-radarr.service"
          ];
          requires = [
            "podman-prowlarr.service"
            "podman-qbittorrent.service"
            "podman-sonarr.service"
            "podman-radarr.service"
          ];
          partOf = ["arr-stack.target"];
          unitConfig.RequiresMountsFor = [cfg.configRoot];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${prowlarrReconcileScript}/bin/arr-prowlarr-reconcile --state ${config.sops.secrets.${cfg.reconcile.stateSecretName}.path}";
            Environment = ["PROWLARR_URL=http://127.0.0.1:9696"];
            EnvironmentFile = config.sops.secrets.${cfg.reconcile.environmentSecretName}.path;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            Restart = "on-failure";
            RestartSec = 15;
            TimeoutStartSec = "5min";
            UMask = "0077";
          };
        };
      })
    ];
  };
}
