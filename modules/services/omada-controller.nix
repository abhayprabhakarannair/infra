{
  config,
  pkgs,
  ...
}: let
  containerHardening = import ./oci-hardening.nix;
  hardening =
    containerHardening.baseline
    ++ containerHardening.withLimits {
      pidsLimit = 2048;
      memory = "4g";
      cpus = 4;
    };
in {
  systemd.tmpfiles.rules = [
    "d /srv/omada-controller 0755 root root -"
    "d /srv/omada-controller/data 0755 root root -"
    "d /srv/omada-controller/work 0755 root root -"
    "d /srv/omada-controller/logs 0755 root root -"
  ];

  virtualisation.oci-containers.containers.omada-controller = {
    image = "mbentley/omada-controller:latest@sha256:a26d3decc71a63ab8b8eb96d5c7d159bef75fcc790ea7d2fa803bccc6a71bf57";
    autoRemoveOnStop = false;

    extraOptions =
      [
        "--network=host"
        "--restart=always"
        "--no-healthcheck"
      ]
      ++ hardening;

    environment = {
      MANAGE_HTTP_PORT = "8088";
      MANAGE_HTTPS_PORT = "8043";
      PORTAL_HTTP_PORT = "8088";
      PORTAL_HTTPS_PORT = "8843";
      SHOW_SERVER_LOGS = "true";
      SHOW_MONGODB_LOGS = "false";
      TZ = "Asia/Kolkata";
    };

    volumes = [
      "/srv/omada-controller/data:/opt/tplink/EAPController/data"
      "/srv/omada-controller/work:/opt/tplink/EAPController/work"
      "/srv/omada-controller/logs:/opt/tplink/EAPController/logs"
    ];
  };
}
