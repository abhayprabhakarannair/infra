{ config, pkgs, inputs, ... }:

let
  immichVersion = "v2";
  
  uploadLocation = "/mnt/homelab/immich/library"; 
  
  dbDataLocation = "/srv/immich/postgres";
  modelCacheLocation = "/srv/immich/model-cache";
in
{
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
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
      environmentFiles = [ config.sops.templates."immich.env".path ];
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
        "--shm-size=128mb"
        "--restart=always"
      ];
    };

    immich-redis = {
      image = "docker.io/valkey/valkey:9@sha256:3b55fbaa0cd93cf0d9d961f405e4dfcc70efe325e2d84da207a0a8e6d8fde4f9";
      autoRemoveOnStop = false;
      extraOptions = [
        "--restart=always"
        "--health-cmd=redis-cli ping || exit 1"
      ];
    };

    immich-server = {
      image = "ghcr.io/immich-app/immich-server:${immichVersion}";
      dependsOn = [ "immich-database" "immich-redis" ];
      autoRemoveOnStop = false;
      environmentFiles = [ config.sops.templates."immich.env".path ];
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
        "--restart=always"
        "--device=/dev/dri:/dev/dri"
      ];
    };

    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:${immichVersion}";
      autoRemoveOnStop = false;
      volumes = [
        "${modelCacheLocation}:/cache"
      ];
      extraOptions = [
        "--restart=always"
        "--shm-size=8gb"
	"--security-opt=seccomp=unconfined"
       ];
    };
  };

  systemd.services.podman-immich-server = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
    bindsTo = [ "rclone-homelab.service" ];
    unitConfig = {
      RequiresMountsFor = "/mnt/homelab/immich";
    };  
  };

  systemd.services.podman-immich-machine-learning = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
    bindsTo = [ "rclone-homelab.service" ];
    unitConfig = {
      RequiresMountsFor = "/mnt/homelab/immich";
    };  
  };
}
