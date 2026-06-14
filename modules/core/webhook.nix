{ config, pkgs, ... }:

let
  wakeScript = pkgs.writeShellScriptBin "wake-device" ''
    TARGET=$1

    case "$TARGET" in
      "devil")
        SECRET_PATH="${config.sops.secrets."devil-mac-address".path}"
        ;;
      "daredevil")
        SECRET_PATH="${config.sops.secrets."daredevil-mac-address".path}"
        ;;
      *)
        echo "Unknown target: $TARGET"
        exit 1
        ;;
    esac

    MAC_ADDRESS=$(cat "$SECRET_PATH")
    ${pkgs.wakeonlan}/bin/wakeonlan "$MAC_ADDRESS"
  '';
in
{
  sops.secrets."devil-mac-address".owner = "webhook";
  sops.secrets."daredevil-mac-address".owner = "webhook";

  services.webhook = {
    enable = true;
    port = 9000;
    hooks.wake = {
      execute-command = "${wakeScript}/bin/wake-device";
      response-message = "Executing wake command...";
      pass-arguments-to-command = [
        {
          source = "url";
          name = "target";
        }
      ];
    };
  };
}
