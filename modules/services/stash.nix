{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /srv/stash 0755 1000 1000 - -"
  ];

  virtualisation.oci-containers.containers.stash = {
    image = "stashapp/stash:latest";
    autoRemoveOnStop = false;
    
    ports = [
      "9999:9999"
    ];
    
    volumes = [
      "/srv/stash:/root/.stash"
      "/mnt/homelab/media/.spice:/data:ro"
    ];
    
    extraOptions = [
      "--restart=always"
      "--no-healthcheck"
    ];
  };

  systemd.services.podman-stash = {
    after = [ "rclone-homelab.service" ];
    requires = [ "rclone-homelab.service" ];
  };
}
