{
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/core.nix"
    "${inputs.self}/modules/storage/persist-backup.nix"
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

  # B2 is the existing second remote used by this node's replication job.
  # Keep the persistence recovery generations independent of the local disk
  # and the canonical StorageBox tree.
  myStorage.persistBackup = {
    enable = true;
    remote = "b2-storage:/disaster-recovery/${config.networking.hostName}";
    configPath = config.sops.secrets."rclone-backup-node.conf".path;
  };
}
