{ pkgs, ... }: {
  networking.hostName = "daredevil";

  # E14 Gen 6 special keys, confirmed with wev. Copilot emits Super+Shift
  # together with XF86Assistant, rather than an unmodified assistant key.
  _module.args.niriHardwareBindings = ''
    Print { screenshot-screen; }
    XF86SelectiveScreenshot { screenshot; }
    XF86LinkPhone { spawn "/home/abhay/.local/bin/power-menu"; }
    XF86Favorites { spawn "${pkgs.thunar}/bin/thunar"; }
    Super+Shift+XF86Assistant { spawn "${pkgs.fuzzel}/bin/fuzzel"; }
    XF86MonBrightnessUp { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"; }
    XF86MonBrightnessDown { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }
    Mod+Space { spawn-sh "current=$(${pkgs.brightnessctl}/bin/brightnessctl -m -d tpacpi::kbd_backlight | ${pkgs.coreutils}/bin/cut -d, -f4); max=$(${pkgs.brightnessctl}/bin/brightnessctl -m -d tpacpi::kbd_backlight | ${pkgs.coreutils}/bin/cut -d, -f5); if [ \"$current\" -ge \"$max\" ]; then ${pkgs.brightnessctl}/bin/brightnessctl -d tpacpi::kbd_backlight set 0; else ${pkgs.brightnessctl}/bin/brightnessctl -d tpacpi::kbd_backlight set 1+; fi"; }
    XF86Display { spawn-sh "exec ${pkgs.util-linux}/bin/flock -n \"$XDG_RUNTIME_DIR/wdisplays.lock\" ${pkgs.wdisplays}/bin/wdisplays"; }
  '';

  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
    ./system.nix
    ./apps.nix
    ./services.nix
  ];
}
