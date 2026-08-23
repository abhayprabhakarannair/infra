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
    mode = "netserver";

    ups.myups = {
      driver = "usbhid-ups";
      port = "auto";
    };

    upsd = {
      enable = true;
      listen = [
        {
          address = "0.0.0.0";
          port = 3493;
        }
      ];
    };

    # 1. NEW: Define the user on the server (upsd) side
    users = {
      admin = {
        passwordFile = "/run/secrets/ups-password";
        upsmon = "primary"; # Grants this user permission to act as the primary monitor
      };
    };

    # 2. upsmon (the client) logs in using those credentials
    upsmon = {
      enable = true;
      monitor = {
        myups = {
          user = "admin";
          passwordFile = "/run/secrets/ups-password";
          system = "myups@localhost";
        };
      };
    };
  };
}
