{ config, pkgs, ... }:

let
  runnerData = "/srv/forgejo-runner";
  hostname = config.networking.hostName;
in {
  sops.secrets."forgejo/${hostname}-uuid" = {};
  sops.secrets."forgejo/${hostname}-token" = {};

  systemd.services.forgejo-runner = {
    description = "Forgejo Actions Runner";
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.git pkgs.nodejs_24 ];

    preStart = ''
      cat > ${runnerData}/config.yml << CONFIG_EOF
log:
  level: info
  job_level: info

runner:
  capacity: 1
  timeout: 3h
  fetch_timeout: 30s
  fetch_interval: 2s

server:
  connections:
    default:
      url: https://git.iamabhay.fyi
      uuid: "$(cat ${config.sops.secrets."forgejo/${hostname}-uuid".path})"
      token: "$(cat ${config.sops.secrets."forgejo/${hostname}-token".path})"
      labels:
        - "ubuntu-latest:host"
CONFIG_EOF
    '';

    serviceConfig = {
      ExecStart = "${pkgs.forgejo-runner}/bin/forgejo-runner daemon -c ${runnerData}/config.yml";
      WorkingDirectory = runnerData;
      User = "1000";
      Group = "1000";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${runnerData} 0750 1000 1000 -"
  ];
}