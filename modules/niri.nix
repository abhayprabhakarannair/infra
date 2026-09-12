{
  lib,
  pkgs,
  ...
}: let
  niriPackage = pkgs.niri.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace resources/niri-session \
          --replace-fail \
            'systemctl --user import-environment' \
            'systemctl --user import-environment $(printenv | cut -d= -f1 | tr "\\n" " ")'
      '';
  });
in {
  _module.args.niriPackage = niriPackage;

  # Let Chromium/CEF applications select their native Wayland backend when
  # they support it. This is also used by Steam's web helper.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --user abhay --cmd ${niriPackage}/bin/niri-session";
        user = "greeter";
      };
    };
  };
}
