{ config, pkgs, inputs, ... }:

let
  runnerData = "/srv/forgejo-runner";
  hostname = config.networking.hostName;
in {
  sops.secrets."forgejo/${hostname}-uuid" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
    owner = "abhay";
  };
  sops.secrets."forgejo/${hostname}-token" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
    owner = "abhay";
  };

  systemd.services.forgejo-runner = {
    description = "Forgejo Actions Runner";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.git pkgs.nodejs_24 pkgs.bash pkgs.coreutils pkgs.nix pkgs.gnutar pkgs.gzip ];

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
      Group = "users";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${runnerData} 0750 1000 users -"
  ];
}