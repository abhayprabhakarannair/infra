{
  config,
  pkgs,
  ...
}: let
  hardening = [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
    "--pids-limit=2048"
    # No memory/CPU ceiling: transcoding and large-library scans are
    # workload-dependent and an artificial ceiling would degrade playback.
  ];
in {
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
      # The shared media mount includes the FLAC music library used by Symfonium.
      "/mnt/homelab/media:/media"
    ];

    extraOptions =
      [
        "--restart=always"
        "--device=/dev/dri:/dev/dri"
        # No read-only root or CPU/memory ceiling: the image's cache/transcode
        # paths are not separately mounted here, and playback/library scans
        # are workload-dependent.
        # The image's healthcheck is intentionally disabled because no
        # in-container probe is guaranteed by this pinned image.
        "--no-healthcheck"
      ]
      ++ hardening;
  };

  systemd.services.podman-jellyfin = {
    after = ["rclone-homelab.service"];
    requires = ["rclone-homelab.service"];
  };
}
