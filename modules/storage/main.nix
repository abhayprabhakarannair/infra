{
  config,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/core.nix"
    "${inputs.self}/modules/storage/persist-backup.nix"
  ];

  sops.secrets."rclone-main.conf" = {
    sopsFile = "${inputs.self}/secrets/rclone/rclone-main.conf";
    format = "binary";
    owner = config.users.users.abhay.name;
    mode = "0400";
  };

  environment.variables = {
    RCLONE_CONFIG = config.sops.secrets."rclone-main.conf".path;
  };

  # The main rclone config already contains the existing `backups:` remote.
  # This is a host-loss recovery copy of /persist, not a live mount or mirror.
  myStorage.persistBackup = {
    enable = true;
    remote = "backups:/disaster-recovery/${config.networking.hostName}";
    configPath = config.sops.secrets."rclone-main.conf".path;
  };
}
