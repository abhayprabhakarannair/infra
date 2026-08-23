{
  config,
  pkgs,
  ...
}: {
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
    extraOptions = [
      "--network=host"
      "--restart=always"
      "--no-healthcheck"
    ];
  };
}
