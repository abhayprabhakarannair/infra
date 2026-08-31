{
  config,
  pkgs,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d /srv/jellyfin 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.jellyfin = {
    image = "jellyfin/jellyfin:latest@sha256:0b901391a662862eddb5dc55d244d7883cbb6236ef5b9a6ea82abc78a89819f0";
    autoRemoveOnStop = false;

    ports = [
      "8096:8096"
    ];

    volumes = [
      "/srv/jellyfin:/config"
      "/mnt/homelab/media:/media"
    ];

    extraOptions = [
      "--restart=always"
      "--device=/dev/dri:/dev/dri"
      "--no-healthcheck"
    ];
  };

  systemd.services.podman-jellyfin = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };
}
