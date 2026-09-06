{inputs, ...}: {
  environment.etc."infra/backup-lib.sh".source = ./backup-lib.sh;

  sops.secrets."known-hosts" = {
    sopsFile = "${inputs.self}/secrets/rclone/secrets.yaml";
    path = "/etc/rclone/known_hosts";
    owner = "root";
    group = "users";
    mode = "0440";
  };
}
