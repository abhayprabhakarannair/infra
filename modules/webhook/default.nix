{
  config,
  pkgs,
  ...
}: let
  wakeScript = pkgs.writeShellApplication {
    name = "wake-device";
    runtimeInputs = [pkgs.wakeonlan];
    text = builtins.readFile (pkgs.replaceVars ./wake.sh {
      devilMacPath = config.sops.secrets."devil-mac-address".path;
      daredevilMacPath = config.sops.secrets."daredevil-mac-address".path;
    });
  };

  shutdownScript = pkgs.writeShellApplication {
    name = "shutdown-device";
    runtimeInputs = [pkgs.openssh];
    text = builtins.readFile ./shutdown.sh;
  };
in {
  sops.secrets = {
    "devil-mac-address".owner = "webhook";
    "daredevil-mac-address".owner = "webhook";
  };

  sops.secrets."webhook-ssh-key" = {
    key = "ssh-private-keys/homelab";
    owner = "webhook";
    mode = "0400";
  };

  services.webhook = {
    enable = true;
    port = 9000;

    hooks = {
      wake = {
        execute-command = "${wakeScript}/bin/wake-device";
        response-message = "Executing wake command...";
        pass-arguments-to-command = [
          {
            source = "url";
            name = "target";
          }
        ];
      };

      shutdown = {
        execute-command = "${shutdownScript}/bin/shutdown-device";
        response-message = "Executing shutdown command...";
        pass-arguments-to-command = [
          {
            source = "url";
            name = "target";
          }
        ];
      };
    };
  };
}
