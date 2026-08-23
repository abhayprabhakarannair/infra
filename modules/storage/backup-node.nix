{
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/core.nix"
  ];

  sops.secrets."rclone-backup-node.conf" = {
    sopsFile = "${inputs.self}/secrets/rclone/rclone-backup-node.conf";
    format = "binary";
    owner = config.users.users.abhay.name;
    mode = "0400";
  };

  environment.variables = {
    RCLONE_CONFIG = config.sops.secrets."rclone-backup-node.conf".path;
  };
}
