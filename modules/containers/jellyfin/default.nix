{

  virtualisation.oci-containers.containers."jellyfin" = {
    image = "lscr.io/linuxserver/jellyfin:latest";
    autoStart = true;
    ports = [ "8096:8096" ];

    volumes = [
      "/var/lib/jellyfin/config:/config"
      "/var/lib/jellyfin/cache:/cache"

      "/mnt/media:/data/media:ro"
    ];

    environment = {
      PUID = "1000";
      PGID = "1000";
      TZ = "Asia/Kolkata";
    };

    extraOptions = [
      "--network=host"
    ];
  };

}
