{ config, pkgs, ... }:

{
  sops.secrets."ssh-private-keys/forgejo-server-key" = {
    mode = "0440"; 
  };

  systemd.tmpfiles.rules = [
    "d /srv/forgejo 0750 1000 1000 -"
  ];

  environment.etc."forgejo-gitconfig".text = ''
    [gpg]
      format = ssh
    [user]
      signingkey = /data/forgejo-server-key
  '';

  virtualisation.oci-containers.containers.forgejo = {
    image = "codeberg.org/forgejo/forgejo:15";
    autoRemoveOnStop = false;
    
    environment = {
      USER_UID = "1000"; 
      USER_GID = "1000";
      TZ = "Asia/Kolkata";
      FORGEJO__server__SSH_PORT = "2222"; 
      "FORGEJO__repository.signing__SIGNING_KEY" = "/data/forgejo-server-key";
      "FORGEJO__repository.signing__SIGNING_NAME" = "Forge";
      "FORGEJO__repository.signing__SIGNING_EMAIL" = "noreply@git.iamabhay.fyi";
      "FORGEJO__repository.signing__MERGES" = "always";
      "FORGEJO__repository.signing__CRUD_ACTIONS" = "always";
      "FORGEJO__git.config__gpg.format" = "ssh";
    };

    ports = [
      "127.0.0.1:3333:3000" 
      "2222:22"
    ];
    
    volumes = [
      "/srv/forgejo:/data"
      "/etc/localtime:/etc/localtime:ro"
      "/run/secrets/ssh-private-keys/forgejo-server-key:/data/forgejo-server-key:ro"
      "/etc/forgejo-gitconfig:/data/git/.gitconfig:ro"   
      ];
    
    extraOptions = [
      "--no-healthcheck"
    ];
  };
}
