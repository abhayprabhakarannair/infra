{ config, pkgs, ... }:

{
  sops.secrets."ssh-private-keys/forgejo-server-key" = {
    owner = "abhay";
    mode = "0400"; 
  };

  systemd.tmpfiles.rules = [
    "d /srv/forgejo 0750 1000 1000 -"
  ];

  environment.etc."forgejo-server-key.pub".text = ''
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMqx32jYbfgpOJY9k3LP2sCkFGiNm6IJ5uY6kDmRUGAG noreply@git.iamabhay.fyi  
  '';

  virtualisation.oci-containers.containers.forgejo = {
    image = "codeberg.org/forgejo/forgejo:15";
    autoRemoveOnStop = false;
    
    environment = {
      USER_UID = "1000"; 
      USER_GID = "1000";
      TZ = "Asia/Kolkata";
      FORGEJO__server__SSH_PORT = "2222"; 

      ${"FORGEJO__repository.signing__FORMAT"} = "ssh";
      
      ${"FORGEJO__repository.signing__SIGNING_KEY"} = "/data/forgejo-server-key.pub";
      ${"FORGEJO__repository.signing__SIGNING_NAME"} = "Forgejo";
      ${"FORGEJO__repository.signing__SIGNING_EMAIL"} = "noreply@git.iamabhay.fyi";
      
      ${"FORGEJO__repository.signing__MERGES"} = "always";
      ${"FORGEJO__repository.signing__CRUD_ACTIONS"} = "always";
    };

    ports = [
      "127.0.0.1:3333:3000" 
      "2222:22"
    ];
    
    volumes = [
      "/srv/forgejo:/data"
      "/etc/localtime:/etc/localtime:ro"
      "/run/secrets/ssh-private-keys/forgejo-server-key:/data/forgejo-server-key:ro"
      "/etc/forgejo-server-key.pub:/data/forgejo-server-key.pub:ro"
    ];
    
    extraOptions = [
      "--no-healthcheck"
      "--security-opt"
      "label=disable"
    ];
  };
}
