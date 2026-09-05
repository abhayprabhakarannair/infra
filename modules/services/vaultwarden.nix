{
  config,
  pkgs,
  ...
}: let
  hardening = [
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
  systemd.tmpfiles.rules = [
    "d /srv/vaultwarden 0750 root root -"
  ];

  virtualisation.oci-containers.containers.vaultwarden = {
    image = "vaultwarden/server:1.37.1@sha256:ebdfe70701c60ac0c28c697e787cea767d7972940b786037b29fe0d507f821e8";
    autoRemoveOnStop = false;

    environment = {
      WEBSOCKET_ENABLED = "true";
      SIGNUPS_ALLOWED = "false";
    };

    ports = [
      "127.0.0.1:8222:80"
    ];

    volumes = [
      "/srv/vaultwarden:/data"
    ];

    extraOptions =
      [
        "--restart=always"
        # The image's health endpoint is not guaranteed to include a probe
        # utility; keep the known-safe no-healthcheck behavior.
        "--no-healthcheck"
      ]
      ++ hardening;
  };
}
