{
  kanagawa,
  niriHardwareBindings ? "",
  niriPackage ? pkgs.niri,
  pkgs,
  ...
}:
{
  environment.systemPackages = [ pkgs.adwaita-icon-theme ];

  home-manager.users.abhay = {
    home.file.".local/bin/power-menu" = {
      executable = true;
      text = ''
        #!/bin/sh

        choice=$(printf '%s\n' \
          'Lock' \
          'Suspend' \
          'Log out' \
          'Reboot' \
          'Power off' \
          | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt '  Power  ' --lines 5 --width 32)

        case "$choice" in
          Lock)
            exec ${pkgs.swaylock}/bin/swaylock -f
            ;;
          Suspend)
            exec ${pkgs.systemd}/bin/systemctl suspend
            ;;
          'Log out')
            exec ${niriPackage}/bin/niri msg action quit --skip-confirmation
            ;;
          Reboot)
            exec ${pkgs.systemd}/bin/systemctl reboot
            ;;
          'Power off')
            exec ${pkgs.systemd}/bin/systemctl poweroff
            ;;
        esac
      '';
    };

    xdg.configFile."niri/config.kdl".text = ''
      input {
        keyboard {
          xkb {
            layout "us"
          }
        }
        touchpad {
          tap
          dwt
          drag true
          click-method "clickfinger"
          natural-scroll
        }
      }

      layout {
        gaps 8
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        focus-ring {
          off
        }
        border {
          on
          width 2
          active-color "#${kanagawa.crystalBlue}"
          inactive-color "#${kanagawa.sumiInk3}"
          urgent-color "#${kanagawa.autumnRed}"
        }
      }

      prefer-no-csd

      cursor {
        xcursor-theme "Adwaita"
        xcursor-size 24
      }

      window-rule {
        match app-id="firefox$"
        exclude title="^Bitwarden"
        exclude title="^Picture-in-Picture$"
        open-maximized true
      }

      hotkey-overlay {
        skip-at-startup
        hide-not-bound
      }

      spawn-at-startup "${pkgs.waybar}/bin/waybar"
      spawn-at-startup "${pkgs.mako}/bin/mako"
      spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet" "--indicator"
      spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-c" "#${kanagawa.sumiInk0}"
      spawn-at-startup "${pkgs.swayidle}/bin/swayidle" "-w" "timeout" "900" "${pkgs.swaylock}/bin/swaylock -f" "before-sleep" "${pkgs.swaylock}/bin/swaylock -f"
      spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

      binds {
        ${niriHardwareBindings}
        Mod+Return { spawn "${pkgs.foot}/bin/foot"; }
        Mod+D { spawn "${pkgs.fuzzel}/bin/fuzzel"; }
        Mod+Shift+P { spawn "/home/abhay/.local/bin/power-menu"; }
        Mod+Ctrl+V { spawn "${pkgs.pavucontrol}/bin/pavucontrol"; }
        Mod+Ctrl+O { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        Mod+Ctrl+M { spawn "/home/abhay/.local/bin/toggle-microphone"; }
        Mod+Q { close-window; }
        Mod+Shift+E { quit; }
        Mod+Alt+L { spawn "${pkgs.swaylock}/bin/swaylock" "-f"; }
        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+L { move-column-right; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+Shift+Page_Down { move-column-to-workspace-down; }
        Mod+Shift+Page_Up { move-column-to-workspace-up; }
        Mod+Tab { toggle-overview; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+O { toggle-window-floating; }
        Mod+Shift+O { switch-focus-between-floating-and-tiling; }
        Mod+Escape { toggle-keyboard-shortcuts-inhibit; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }
        Mod+Shift+S { screenshot; }
        XF86AudioRaiseVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "--limit" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "--limit" "1.0" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute { spawn "/home/abhay/.local/bin/toggle-microphone"; }
        XF86AudioPlay { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
        XF86AudioNext { spawn "${pkgs.playerctl}/bin/playerctl" "next"; }
        XF86AudioPrev { spawn "${pkgs.playerctl}/bin/playerctl" "previous"; }
      }
    '';

    xdg.configFile."waybar/config.jsonc".text = builtins.toJSON {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;
      modules-left = [ "niri/workspaces" ];
      modules-center = [ "niri/window" ];
      modules-right = [
        "network"
        "wireplumber"
        "wireplumber#source"
        "backlight"
        "battery"
        "clock"
        "tray"
        "custom/power"
      ];
      "niri/workspaces" = {
        format = "{icon}";
        "format-icons" = {
          active = "";
          default = "";
          urgent = "";
        };
        "on-click" = "activate";
      };
      "niri/window" = {
        format = "{}";
        "max-length" = 60;
        "separate-outputs" = true;
      };
      network = {
        format-wifi = "{icon}";
        "format-ethernet" = "󰈀";
        "format-disconnected" = "󰤮";
        "format-disabled" = "󰤭";
        "format-icons" = [
          "󰤯"
          "󰤟"
          "󰤢"
          "󰤥"
          "󰤨"
        ];
        "tooltip-format-wifi" = "{essid} ({signalStrength}%)";
        "tooltip-format-ethernet" = "Ethernet";
      };
      wireplumber = {
        format = "{icon} {volume}%";
        "format-muted" = "󰝟 muted";
        "format-icons" = [
          ""
          ""
          " "
        ];
        "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
        "on-click-middle" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "on-scroll-up" = "${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        "on-scroll-down" = "${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%-";
        "scroll-step" = 5;
        "tooltip-format" = "Output: {volume}%";
      };
      "wireplumber#source" = {
        "node-type" = "Audio/Source";
        format = "󰍬 {volume}%";
        "format-muted" = "󰍭 muted";
        "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
        "on-click-middle" = "/home/abhay/.local/bin/toggle-microphone";
        "on-scroll-up" = "${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SOURCE@ 5%+";
        "on-scroll-down" =
          "${pkgs.wireplumber}/bin/wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SOURCE@ 5%-";
        "scroll-step" = 5;
        "tooltip-format" =
          "Microphone gain: {volume}% (not a sound meter). Scroll to adjust; middle-click to mute.";
      };
      backlight = {
        format = "{icon} {percent}%";
        "format-icons" = [
          "󰃞"
          "󰃟"
          "󰃝"
          "󰃠"
        ];
        "on-scroll-up" = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        "on-scroll-down" = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
      };
      battery = {
        bat = "BAT0";
        adapter = "AC";
        format = "{icon} {capacity}%";
        "format-charging" = "󰂄 {capacity}%";
        "format-plugged" = "󰚥 {capacity}%";
        "format-icons" = [
          "󰂎"
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
        states = {
          warning = 30;
          critical = 15;
        };
        "tooltip-format" = "Battery: {capacity}% — {status}";
      };
      clock = {
        format = " {:%H:%M}";
        "tooltip-format" = "{:%A, %d %B %Y\n%H:%M}";
      };
      "custom/power" = {
        format = "";
        "tooltip" = true;
        "tooltip-format" = "Power menu";
        "on-click" = "/home/abhay/.local/bin/power-menu";
      };
      tray = {
        spacing = 6;
        "icon-size" = 16;
      };
    };

    xdg.configFile."waybar/style.css".text = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font", "Inter", sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: #${kanagawa.sumiInk1};
        border-bottom: 1px solid #${kanagawa.sumiInk3};
        color: #${kanagawa.fujiWhite};
      }

      #workspaces button {
        background: transparent;
        box-shadow: none;
        text-shadow: none;
        transition: none;
        color: #${kanagawa.fujiGray};
        min-width: 18px;
        padding: 0 5px;
      }

      #workspaces button:hover {
        background: #${kanagawa.sumiInk3};
        border-radius: 6px;
        box-shadow: none;
        text-shadow: none;
        color: #${kanagawa.fujiWhite};
      }

      #workspaces button.active,
      #workspaces button.active:hover {
        background: #${kanagawa.sumiInk2};
        border-radius: 6px;
        color: #${kanagawa.crystalBlue};
      }

      #workspaces button.urgent {
        color: #${kanagawa.autumnRed};
      }

      #window,
      #network,
      #wireplumber,
      #wireplumber.source,
      #backlight,
      #battery,
      #clock,
      #custom-power,
      #tray {
        padding: 0 7px;
      }

      #window {
        color: #${kanagawa.oldWhite};
      }

      #network,
      #wireplumber,
      #wireplumber.source,
      #backlight {
        color: #${kanagawa.springBlue};
      }

      #battery {
        color: #${kanagawa.springGreen};
      }

      #battery.warning {
        color: #${kanagawa.boatYellow};
      }

      #battery.critical,
      #custom-power {
        color: #${kanagawa.autumnRed};
      }

      tooltip {
        background: #${kanagawa.sumiInk1};
        border: 1px solid #${kanagawa.crystalBlue};
        color: #${kanagawa.fujiWhite};
      }

      #tray {
        margin-left: 2px;
      }
    '';

    xdg.configFile."mako/config".text = ''
      font=Inter 11
      background-color=#${kanagawa.sumiInk1}
      text-color=#${kanagawa.fujiWhite}
      border-color=#${kanagawa.crystalBlue}
      progress-color=over #${kanagawa.crystalBlue}
      border-size=2
      border-radius=10
      padding=10
      margin=10
      default-timeout=5000
    '';

    xdg.configFile."fuzzel/fuzzel.ini".text = ''
      [main]
      font=Inter:size=12
      width=50
      horizontal-pad=16
      vertical-pad=12
      inner-pad=8

      [colors]
      background=${kanagawa.sumiInk1}f2
      text=${kanagawa.fujiWhite}ff
      match=${kanagawa.springBlue}ff
      selection=${kanagawa.sumiInk2}ff
      selection-text=${kanagawa.fujiWhite}ff
      border=${kanagawa.crystalBlue}ff

      [border]
      width=2
      radius=10
    '';

    xdg.configFile."swaylock/config".text = ''
      color=${kanagawa.sumiInk0}
      inside-color=${kanagawa.sumiInk1}
      ring-color=${kanagawa.crystalBlue}
      line-color=${kanagawa.sumiInk1}
      text-color=${kanagawa.fujiWhite}
      inside-clear-color=${kanagawa.waveBlue2}
      ring-clear-color=${kanagawa.springBlue}
      inside-ver-color=${kanagawa.sumiInk2}
      ring-ver-color=${kanagawa.springGreen}
      inside-wrong-color=${kanagawa.sumiInk2}
      ring-wrong-color=${kanagawa.autumnRed}
      font=Inter
      font-size=24
      indicator-idle-visible
    '';
  };
}
