{
  config,
  pkgs,
  ...
}: let
  containerHardening = import ./oci-hardening.nix;
  hardening = containerHardening.immutableWithLimits {
    pidsLimit = 1024;
    memory = "4g";
    cpus = 4;
  };
in {
  systemd.tmpfiles.rules = [
    "d /srv/stash 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.stash = {
    image = "stashapp/stash:latest@sha256:736e7cd8f61c815c08fd3048792982a61e619735bb1808cd279f0f2fa857c4b0";
    autoRemoveOnStop = false;

    ports = [
      "9999:9999"
    ];

    volumes = [
      "/srv/stash:/root/.stash"
      "/mnt/homelab/media/.spice:/data:ro"
    ];

    extraOptions =
      [
        "--no-healthcheck"
      ]
      ++ hardening;
  };

  systemd.services.podman-stash = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };
}
