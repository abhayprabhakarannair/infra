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

  # old-devil monitors this UPS over Tailscale. Keep NUT's port off the WAN
  # and other interfaces; the common firewall already trusts tailscale0.

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

    users = {
      admin = {
        passwordFile = "/run/secrets/ups-password";
        upsmon = "primary";
      };
    };

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
