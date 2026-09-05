{
  config,
  pkgs,
  ...
}: let
  hardening = [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
    "--cap-add=NET_BIND_SERVICE"
    "--read-only"
    "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
    "--tmpfs=/run:rw,nosuid,nodev"
    "--pids-limit=512"
    "--memory=1g"
    "--cpus=2"
  ];
in {
  systemd.tmpfiles.rules = [
    "d /srv/technitium 0755 root root -"
  ];

  virtualisation.oci-containers.containers.technitium = {
    image = "technitium/dns-server:latest@sha256:b2b6eeeae5057880c7403da426907ccd83070b5c7a1ecfb12135d98b9f4a0b9e";
    autoRemoveOnStop = false;
    ports = [
      "53:53/udp"
      "53:53/tcp"
      "8085:8085/tcp"
    ];
    volumes = [
      "/srv/technitium:/etc/dns"
    ];
    extraOptions =
      [
        # Host networking is required for DNS service discovery and binding.
        "--network=host"
        "--restart=always"
        "--no-healthcheck"
      ]
      ++ hardening;
  };
}
