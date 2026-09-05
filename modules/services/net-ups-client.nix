{
  pkgs,
  inputs,
  ...
}: {
  sops.secrets."ups-password" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };

  environment.systemPackages = with pkgs; [
    nut
  ];

  power.ups = {
    enable = true;
    mode = "netclient"; # MUST be netclient
    upsmon.monitor = {
      myups = {
        user = "admin";
        passwordFile = "/run/secrets/ups-password";
        system = "myups@devil";
      };
    };
  };
}
