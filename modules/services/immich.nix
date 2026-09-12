{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.services.immich;
  serviceSecretsFile = "${inputs.self}/secrets/service-secrets.yaml";
  restoreRoot = "${cfg.configRoot}/restore";

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

  restoreScript = pkgs.writeShellApplication {
    name = "immich-restore";
    runtimeInputs = with pkgs; [
      coreutils
      gzip
      podman
      systemd
    ];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ]; then
        echo "usage: immich-restore /path/to/immich-db-backup.sql.gz" >&2
        exit 2
      fi

      backup=$1
      test -r "$backup" || {
        echo "Immich backup is not readable: $backup" >&2
        exit 1
      }

      staged="${restoreRoot}/$(basename -- "$backup")"
      mkdir -p "${restoreRoot}"
      if [ "$backup" != "$staged" ]; then
        cp --reflink=auto -- "$backup" "$staged"
      fi
      gzip -t "$staged"

      systemctl stop immich.target || true
      systemctl start podman-immich-database.service

      ready=false
      for _ in $(seq 1 60); do
        if podman exec immich-database pg_isready -U postgres -d immich >/dev/null 2>&1; then
          ready=true
          break
        fi
        sleep 1
      done

      if [ "$ready" != true ]; then
        echo "Immich PostgreSQL did not become ready" >&2
        exit 1
      fi

      table_count=$(podman exec immich-database psql -Atq -U postgres -d immich \
        -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
      if [ "$table_count" != 0 ]; then
        echo "Refusing to restore over a non-empty Immich database" >&2
        exit 1
      fi

      if ! gzip -dc "$staged" | podman exec -i immich-database \
        psql -v ON_ERROR_STOP=1 -U postgres -d immich; then
        echo "Immich database restore failed; resetting the empty database for retry" >&2
        podman exec immich-database psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
          -c "DROP DATABASE immich"
        podman exec immich-database psql -v ON_ERROR_STOP=1 -U postgres -d postgres \
          -c "CREATE DATABASE immich"
        exit 1
      fi

      systemctl start immich.target
      echo "Immich database restored from $staged"
    '';
  };
in {
  options.my.services.immich = {
    enable = lib.mkEnableOption "the Immich photo management service";

    uploadRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/homelab-storage-one/immich/library";
      description = "Existing Immich UPLOAD_LOCATION root on authoritative storage.";
    };

    uploadMountRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/homelab-storage-one";
      description = "Actual rclone mount containing uploadRoot.";
    };

    configRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persistent/services/immich";
      description = "Persistent local Immich service state.";
    };

    databaseRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persistent/services/immich/postgres";
      description = "Local PostgreSQL data directory for Immich.";
    };

    modelCacheRoot = lib.mkOption {
      type = lib.types.str;
      default = "/persistent/cache/immich-model";
      description = "Local rebuildable cache for Immich machine-learning models.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which Immich is published.";
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID used by Immich when writing the rclone-backed upload tree.";
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "GID used by Immich when writing the rclone-backed upload tree.";
    };

    startOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the Immich target automatically with multi-user.target.";
    };

    databasePasswordSecretName = lib.mkOption {
      type = lib.types.str;
      default = "immich/db-password";
      description = "SOPS secret containing the Immich PostgreSQL password.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.podman.enable;
        message = "my.services.immich requires my.services.podman.enable = true";
      }
      {
        assertion = config.my.services.homelabMounts.enable;
        message = "my.services.immich requires my.services.homelabMounts.enable = true";
      }
    ];

    sops.secrets.${cfg.databasePasswordSecretName} = {
      sopsFile = serviceSecretsFile;
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [
        "podman-immich-database.service"
        "podman-immich-server.service"
      ];
    };

    sops.templates."immich.env" = {
      content = ''
        DB_PASSWORD=${config.sops.placeholder.${cfg.databasePasswordSecretName}}
        POSTGRES_PASSWORD=${config.sops.placeholder.${cfg.databasePasswordSecretName}}
      '';
      restartUnits = [
        "podman-immich-database.service"
        "podman-immich-server.service"
      ];
    };

    environment.systemPackages = [restoreScript];

    systemd.tmpfiles.rules = [
      "d ${cfg.configRoot} 0750 root root -"
      "d ${restoreRoot} 0700 root root -"
      "d ${cfg.databaseRoot} 0750 1000 100 -"
      "d ${cfg.modelCacheRoot} 0750 1000 100 -"
    ];

    virtualisation.oci-containers = {
      backend = "podman";
      containers = {
        immich-database = {
          image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
          autoStart = false;
          autoRemoveOnStop = false;
          environmentFiles = [config.sops.templates."immich.env".path];
          environment = {
            POSTGRES_USER = "postgres";
            POSTGRES_DB = "immich";
            POSTGRES_INITDB_ARGS = "--data-checksums";
          };
          volumes = [
            "${cfg.databaseRoot}:/var/lib/postgresql/data"
          ];
          extraOptions = [
            "--security-opt=no-new-privileges"
            "--cap-drop=ALL"
            "--cap-add=CHOWN"
            "--cap-add=DAC_OVERRIDE"
            "--cap-add=FOWNER"
            "--cap-add=SETGID"
            "--cap-add=SETUID"
            "--pids-limit=1024"
            "--memory=4g"
            "--cpus=4"
            "--shm-size=128mb"
          ];
        };

        immich-redis = {
          image = "docker.io/valkey/valkey:9@sha256:8e8d64b405ce18f41b8e5ee20aa4687a8ed0022d1298f2ce31cdcf3a76e09411";
          autoStart = false;
          autoRemoveOnStop = false;
          extraOptions = [
            "--security-opt=no-new-privileges"
            "--cap-drop=ALL"
            "--cap-add=SETGID"
            "--cap-add=SETUID"
            "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
            "--tmpfs=/run:rw,nosuid,nodev"
            "--pids-limit=512"
            "--memory=1g"
            "--cpus=2"
            "--health-cmd=redis-cli ping || exit 1"
            "--health-interval=30s"
            "--health-timeout=5s"
            "--health-retries=3"
            "--health-start-period=20s"
          ];
        };

        immich-server = {
          image = "ghcr.io/immich-app/immich-server:v3.1.0@sha256:079cc990b26a88d71f96027341c67329cb11829d4c341ce33b3718fe0f84cbfa";
          autoStart = false;
          autoRemoveOnStop = false;
          user = "${toString cfg.uid}:${toString cfg.gid}";
          dependsOn = ["immich-database" "immich-redis"];
          environmentFiles = [config.sops.templates."immich.env".path];
          environment = {
            DB_HOSTNAME = "immich-database";
            DB_USERNAME = "postgres";
            DB_DATABASE_NAME = "immich";
            REDIS_HOSTNAME = "immich-redis";
            UPLOAD_LOCATION = "/data";
            IMMICH_MACHINE_LEARNING_URL = "http://immich-machine-learning:3003";
          };
          ports = ["${cfg.listenAddress}:2283:2283"];
          volumes = [
            "${cfg.uploadRoot}:/data"
            "/etc/localtime:/etc/localtime:ro"
          ];
          extraOptions =
            (hardened {
              pidsLimit = 1024;
              memory = "4g";
              cpus = 4;
            })
            ++ ["--device=/dev/dri:/dev/dri"];
        };

        immich-machine-learning = {
          image = "ghcr.io/immich-app/immich-machine-learning:v3.1.0@sha256:5a0839dc5303cd7215bcd2180a26aed3af41675aefb3e75e5157e9f10ad16e6e";
          autoStart = false;
          autoRemoveOnStop = false;
          volumes = [
            "${cfg.modelCacheRoot}:/cache"
          ];
          extraOptions =
            (hardened {
              pidsLimit = 1024;
              memory = "8g";
              cpus = 8;
            })
            ++ [
              "--shm-size=8gb"
              "--security-opt=seccomp=unconfined"
            ];
        };
      };
    };

    systemd.targets.immich = {
      description = "Immich photo management stack";
      wantedBy = lib.optional cfg.startOnBoot "multi-user.target";
      wants = [
        "network-online.target"
        "podman-immich-database.service"
        "podman-immich-redis.service"
        "podman-immich-server.service"
        "podman-immich-machine-learning.service"
      ];
      after = ["network-online.target"];
      unitConfig = {
        RequiresMountsFor = [
          cfg.configRoot
          cfg.databaseRoot
          cfg.modelCacheRoot
        ];
      };
    };

    systemd.services = {
      podman-immich-database = {
        partOf = ["immich.target"];
        unitConfig.RequiresMountsFor = [cfg.databaseRoot];
        serviceConfig.RestartSec = 10;
      };

      podman-immich-redis = {
        partOf = ["immich.target"];
        serviceConfig.RestartSec = 10;
      };

      podman-immich-server = {
        after = [
          "rclone-homelab-storage-one.service"
          "podman-immich-database.service"
          "podman-immich-redis.service"
        ];
        requires = [
          "rclone-homelab-storage-one.service"
          "podman-immich-database.service"
          "podman-immich-redis.service"
        ];
        bindsTo = ["rclone-homelab-storage-one.service"];
        partOf = ["immich.target"];
        unitConfig = {
          RequiresMountsFor = [cfg.uploadRoot cfg.databaseRoot];
          ConditionPathIsMountPoint = cfg.uploadMountRoot;
          ConditionPathIsDirectory = cfg.uploadRoot;
        };
        serviceConfig.RestartSec = 10;
      };

      podman-immich-machine-learning = {
        after = ["podman-immich-server.service"];
        partOf = ["immich.target"];
        unitConfig.RequiresMountsFor = [cfg.modelCacheRoot];
        serviceConfig.RestartSec = 10;
      };
    };
  };
}
