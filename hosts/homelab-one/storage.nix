{config, pkgs, inputs, ...}:

{
  imports = [
   "${inputs.self}/modules/storage/backup-node.nix"
  ];

  systemd.timers.backup-homelab-storage-one = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      Persistent = true;
    };
  };

  systemd.services.backup-homelab-storage-one = {
    description = "Mirror StorageBox to Backblaze B2";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone sync homelab-storage-one:/ b2-storage:homelab-storage-one-replica/ \
          --config=${config.sops.secrets."rclone-backup-node.conf".path} \
          --fast-list \
          --transfers 4 \
          --checkers 8 \
          --contimeout 1m \
          --low-level-retries 10      
	'';
    };
  };

}
