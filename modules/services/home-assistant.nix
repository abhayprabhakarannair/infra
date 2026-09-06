{
  config,
  pkgs,
  ...
}: let
  containerHardening = import ./oci-hardening.nix;
  hardening =
    containerHardening.baseline
    ++ containerHardening.immutable
    ++ containerHardening.withLimits {
      pidsLimit = 1024;
      memory = "2g";
      cpus = 4;
    };
in {
  systemd.tmpfiles.rules = [
    "d /srv/home-assistant 0755 root root -"
  ];

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable@sha256:6e8225ea9de2cfe9292b634e554ebbf439118ca0c823221d794298e7a74404bb";
    autoRemoveOnStop = false;

    extraOptions =
      [
        "--network=host"
      ]
      ++ hardening;

    environment = {
      TZ = "Asia/Kolkata";
    };

    volumes = [
      "/srv/home-assistant:/config"
    ];
  };

  networking.firewall.allowedTCPPorts = [8123];
}
