{
  config,
  pkgs,
  inputs,
  ...
}: let
  uploadLocation = "/mnt/homelab/immich/library";

  dbDataLocation = "/srv/immich/postgres";
  # Model data is reconstructible and should not be retained as service state.
  # Keep it outside /srv so the impermanence allowlist does not preserve it.
  modelCacheLocation = "/var/cache/immich-model";
  hardened = [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
    "--read-only"
    "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
    "--tmpfs=/run:rw,nosuid,nodev"
  ];
in {
  sops.secrets."immich/db-password" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };

  sops.templates."immich.env" = {
    content = ''
      DB_PASSWORD=${config.sops.placeholder."immich/db-password"}
      POSTGRES_PASSWORD=${config.sops.placeholder."immich/db-password"}
    '';
    restartUnits = [
      "podman-immich-database.service"
      "podman-immich-server.service"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${dbDataLocation} 0755 1000 1000 - -"
    "d ${modelCacheLocation} 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers = {
    immich-database = {
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:b1d33572a9a0634aa6d344077467ad32847812a37fa3859f702952cba22a2f55";
      environmentFiles = [config.sops.templates."immich.env".path];
      autoRemoveOnStop = false;
      environment = {
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "immich";
        POSTGRES_INITDB_ARGS = "--data-checksums";
      };
      volumes = [
        "${dbDataLocation}:/var/lib/postgresql/data"
      ];
      extraOptions = [
        # PostgreSQL manages runtime files and shared memory itself; its data
        # directory is already isolated to the dedicated bind mount. Avoid a
        # read-only root and tight memory cap for database safety.
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--pids-limit=1024"
        "--memory=4g"
        "--cpus=4"
        "--shm-size=128mb"
        "--restart=always"
      ];
    };

    immich-redis = {
      image = "docker.io/valkey/valkey:9@sha256:2f4a4b0a42a72569b40567fae9016dc54aa76736250be28120b5fced8050c0f0";
      autoRemoveOnStop = false;
      extraOptions = [
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--read-only"
        "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
        "--tmpfs=/run:rw,nosuid,nodev"
        "--pids-limit=512"
        "--memory=1g"
        "--cpus=2"
        "--restart=always"
        "--health-cmd=redis-cli ping || exit 1"
        "--health-interval=30s"
        "--health-timeout=5s"
        "--health-retries=3"
        "--health-start-period=20s"
      ];
    };

    immich-server = {
      image = "ghcr.io/immich-app/immich-server:v3@sha256:079cc990b26a88d71f96027341c67329cb11829d4c341ce33b3718fe0f84cbfa";
      dependsOn = ["immich-database" "immich-redis"];
      autoRemoveOnStop = false;
      environmentFiles = [config.sops.templates."immich.env".path];
      environment = {
        DB_HOSTNAME = "immich-database";
        DB_USERNAME = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich-redis";
        UPLOAD_LOCATION = "/data";
      };
      ports = [
        "2283:2283"
      ];
      volumes = [
        "${uploadLocation}:/data"
        "/etc/localtime:/etc/localtime:ro"
      ];
      extraOptions = [
        # Immich needs its upload bind mount and device access. Keep the image
        # root writable until the upstream image's runtime write set is
        # verified against this pinned image digest.
        "--security-opt=no-new-privileges"
        "--cap-drop=ALL"
        "--pids-limit=1024"
        "--memory=4g"
        "--cpus=4"
        "--restart=always"
        "--device=/dev/dri:/dev/dri"
      ];
    };

    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:v3@sha256:a25ddad7d6d2ab18a161176731dc171bb7e39c0e9dd3884fb1ec629dab535d05";
      autoRemoveOnStop = false;
      volumes = [
        "${modelCacheLocation}:/cache"
      ];
      extraOptions =
        hardened
        ++ [
          # Model workers can use substantial CPU/RAM and temporary runtime
          # files, so only the root filesystem and capabilities are restricted.
          "--pids-limit=1024"
          "--memory=8g"
          "--cpus=8"
          "--restart=always"
          "--shm-size=8gb"
          # The pinned ML image's Python/native dependencies have not been
          # runtime-tested under the default seccomp profile. Preserve this
          # existing exception until an offline container smoke test proves it
          # can be removed.
          "--security-opt=seccomp=unconfined"
        ];
    };
  };

  systemd.services.podman-immich-server = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
    bindsTo = ["rclone-homelab.service"];
    unitConfig = {
      RequiresMountsFor = "/mnt/homelab/immich";
    };
  };

  systemd.services.podman-immich-machine-learning = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
    bindsTo = ["rclone-homelab.service"];
    unitConfig = {
      RequiresMountsFor = "/mnt/homelab/immich";
    };
  };
}
