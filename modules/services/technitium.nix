
{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/technitium 0755 root root -"
  ];

  virtualisation.oci-containers.containers.technitium = {
    image = "technitium/dns-server:latest";
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
    ];
  };
}
