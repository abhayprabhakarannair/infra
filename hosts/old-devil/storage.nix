{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    "${inputs.self}/modules/storage/main.nix"
    "${inputs.self}/modules/syncthing"
  ];

  systemd.services.sync-private-to-homelab-storage-one = {
    description = "Encrypt and Sync Local Private Folder to Homelab Storage One";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone sync /home/${config.users.users."abhay".name}/Sync/Private private: \
          --config=${config.sops.secrets."rclone-main.conf".path} \
          --fast-list
      '';
    };
  };

  systemd.timers.sync-private-to-homelab-storage-one = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
