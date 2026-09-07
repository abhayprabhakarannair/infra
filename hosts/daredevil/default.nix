{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  kanagawa = {
    sumiInk0 = "16161d";
    sumiInk1 = "1f1f28";
    sumiInk2 = "2a2a37";
    sumiInk3 = "363646";
    waveBlue2 = "223249";
    fujiWhite = "dcd7ba";
    oldWhite = "c8c093";
    fujiGray = "727169";
    crystalBlue = "7e9cd8";
    springBlue = "7fb4ca";
    sakuraPink = "d27e99";
    autumnRed = "c34043";
    springGreen = "98bb6c";
    boatYellow = "e6c384";
  };
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
  ];

  home-manager.users.abhay = {
    home.username = "abhay";
    home.homeDirectory = "/home/abhay";
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
    programs.bash.enable = true;
    programs.bash.shellAliases = {
      ll = "ls -larth";
      nrb = "nixos-rebuild build --flake ~/Projects/infra#daredevil";
      nrs = "nixos-rebuild switch --flake ~/Projects/infra#daredevil";
      ve = "nvim .";
    };
    programs.bash.initExtra = ''
      PS1='\[\e[38;2;126;156;216m\]\u@\h \[\e[38;2;114;113;105m\]\w \[\e[38;2;152;187;108m\]\$\[\e[0m\] '
    '';

    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono:size=11";
          pad = "12x10";
          dpi-aware = "yes";
          term = "xterm-256color";
        };
        scrollback = {
          lines = 10000;
          multiplier = 3;
        };
        cursor = {
          style = "beam";
          blink = "yes";
        };
        mouse.hide-when-typing = "yes";
        "colors-dark" = {
          alpha = "0.96";
          background = kanagawa.sumiInk1;
          foreground = kanagawa.fujiWhite;
          regular0 = kanagawa.sumiInk1;
          regular1 = kanagawa.autumnRed;
          regular2 = kanagawa.springGreen;
          regular3 = kanagawa.boatYellow;
          regular4 = kanagawa.crystalBlue;
          regular5 = kanagawa.sakuraPink;
          regular6 = kanagawa.springBlue;
          regular7 = kanagawa.fujiWhite;
          bright0 = kanagawa.sumiInk3;
          bright1 = kanagawa.autumnRed;
          bright2 = kanagawa.springGreen;
          bright3 = kanagawa.boatYellow;
          bright4 = kanagawa.crystalBlue;
          bright5 = kanagawa.sakuraPink;
          bright6 = kanagawa.springBlue;
          bright7 = "ffffff";
          selection-foreground = kanagawa.sumiInk1;
          selection-background = kanagawa.crystalBlue;
        };
        key-bindings = {
          scrollback-up-page = "Page_Up";
          scrollback-down-page = "Page_Down";
          clipboard-copy = "Control+Shift+c";
          clipboard-paste = "Control+Shift+v";
        };
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "abhayprabhakarannair";
          email = "abhayprabhakarannair@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        ServerAliveInterval = 60;
      };
    };

    home.packages = with pkgs; [
      age
      alejandra
      curl
      evince
      fastfetch
      file-roller
      gcc
      gh
      gnumake
      gnome-calculator
      gnome-text-editor
      inter
      jq
      loupe
      nil
      nixd
      nodejs
      pavucontrol
      python3
      ripgrep
      rustup
      sops
      ssh-to-age
      stylua
      tree
      unzip
      vlc
      wget
      wdisplays
      zed-editor
    ];

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "/home/abhay/Desktop";
      documents = "/home/abhay/Documents";
      download = "/home/abhay/Downloads";
      music = "/home/abhay/Music";
      pictures = "/home/abhay/Pictures";
      publicShare = "/home/abhay/Public";
      templates = "/home/abhay/Templates";
      videos = "/home/abhay/Videos";
    };

    home.file.".config/zed/settings.json".text = builtins.toJSON {
      theme = "Kanagawa";
      buffer_font_family = "JetBrains Mono";
      buffer_font_size = 15;
      ui_font_family = "Inter";
      ui_font_size = 14;
      autosave = "on_focus_change";
      format_on_save = "on";
      terminal = {
        shell = {
          program = "bash";
        };
      };
    };

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
            exec ${pkgs.niri}/bin/niri msg action quit --skip-confirmation
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

    home.file.".config/firefox/startpage.html".text = ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>daredevil</title>
          <style>
            :root {
              color-scheme: dark;
              --background: #${kanagawa.sumiInk0};
              --surface: #${kanagawa.sumiInk1};
              --border: #${kanagawa.crystalBlue};
              --text: #${kanagawa.fujiWhite};
              --muted: #${kanagawa.fujiGray};
              --accent: #${kanagawa.springBlue};
            }

            * {
              box-sizing: border-box;
            }

            body {
              align-items: center;
              background: var(--background);
              color: var(--text);
              display: flex;
              font-family: Inter, system-ui, sans-serif;
              justify-content: center;
              margin: 0;
              min-height: 100vh;
            }

            main {
              margin-top: -8vh;
              text-align: center;
              width: min(720px, 86vw);
            }

            img {
              height: 112px;
              margin-bottom: 28px;
              width: 112px;
            }

            form {
              align-items: center;
              background: var(--surface);
              border: 1px solid var(--border);
              border-radius: 16px;
              box-shadow: 0 10px 40px rgba(0, 0, 0, 0.24);
              display: flex;
              padding: 6px 10px 6px 20px;
            }

            input {
              background: transparent;
              border: 0;
              color: var(--text);
              flex: 1;
              font: inherit;
              font-size: 1.1rem;
              outline: 0;
              padding: 14px 0;
            }

            input::placeholder {
              color: var(--muted);
            }

            button {
              background: var(--accent);
              border: 0;
              border-radius: 11px;
              color: #${kanagawa.sumiInk1};
              cursor: pointer;
              font: inherit;
              font-weight: 700;
              padding: 12px 18px;
            }

            nav {
              display: flex;
              gap: 22px;
              justify-content: center;
              margin-top: 22px;
            }

            a {
              color: var(--muted);
              font-size: 0.9rem;
              text-decoration: none;
            }

            a:hover {
              color: var(--accent);
            }
          </style>
        </head>
        <body>
          <main>
            <img src="file://${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg" alt="NixOS">
            <form action="https://duckduckgo.com/" method="get">
              <input autofocus name="q" placeholder="Search the web" type="search">
              <button type="submit">Search</button>
            </form>
            <nav>
              <a href="https://wiki.nixos.org/">NixOS Wiki</a>
              <a href="https://github.com/">GitHub</a>
            </nav>
          </main>
        </body>
      </html>
    '';

    gtk = {
      enable = true;
      colorScheme = "dark";
      iconTheme = {
        name = "Kanagawa";
        package = pkgs.kanagawa-icon-theme;
      };
      theme = {
        name = "Kanagawa";
        package = pkgs.kanagawa-gtk-theme;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-esr;
      profiles.abhay = {
        isDefault = true;

        settings = {
          "browser.startup.page" = 1;
          "browser.startup.homepage" = "file:///home/abhay/.config/firefox/startpage.html";
          "browser.newtabpage.enabled" = false;
          "browser.uidensity" = 1;
          "browser.compactmode.show" = true;
          "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
          "browser.newtabpage.activity-stream.feeds.system.topstories" = false;
          "browser.newtabpage.activity-stream.feeds.snippets" = false;
          "browser.newtabpage.activity-stream.feeds.telemetry" = false;
          "browser.newtabpage.activity-stream.showHighlights" = false;
          "browser.newtabpage.activity-stream.showSponsored" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.discovery.enabled" = false;
          "extensions.pocket.enabled" = false;
          "browser.urlbar.suggest.searches" = false;
          "browser.urlbar.suggest.topsites" = false;
          "browser.urlbar.quicksuggest.enabled" = false;
          "browser.urlbar.quicksuggest.sponsored" = false;
          "signon.rememberSignons" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "datareporting.healthreport.uploadEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;
          "browser.ping-centre.telemetry" = false;
          "browser.newtabpage.activity-stream.telemetry" = false;
          "app.shield.optoutstudies.enabled" = false;
        };

        userChrome = ''
          :root {
            --kanagawa-blue: #${kanagawa.crystalBlue};
            --kanagawa-blue-bright: #${kanagawa.springBlue};
            --kanagawa-surface: #${kanagawa.sumiInk1};
            --kanagawa-surface-raised: #${kanagawa.sumiInk2};
            --kanagawa-text: #${kanagawa.fujiWhite};
          }

          #navigator-toolbox,
          #TabsToolbar,
          #nav-bar {
            background: var(--kanagawa-surface) !important;
            color: var(--kanagawa-text) !important;
          }

          #urlbar-background,
          #searchbar {
            background: var(--kanagawa-surface-raised) !important;
            border: 1px solid var(--kanagawa-blue) !important;
          }

          .tab-background[selected="true"] {
            background: var(--kanagawa-surface-raised) !important;
            box-shadow: inset 0 2px var(--kanagawa-blue-bright) !important;
          }

          #nav-bar {
            border-top: 1px solid var(--kanagawa-blue) !important;
            min-height: 34px !important;
            padding-block: 2px !important;
          }

          #TabsToolbar {
            min-height: 30px !important;
          }

          .tabbrowser-tab {
            min-height: 30px !important;
            padding-inline: 4px !important;
          }

          #urlbar {
            min-height: 29px !important;
          }

          #home-button,
          #library-button,
          #sidebar-button,
          #save-to-pocket-button,
          #fxa-toolbar-menu-button {
            display: none !important;
          }
        '';

        search = {
          default = "ddg";
          privateDefault = "ddg";
          force = true;
          order = ["ddg" "google" "nixos-wiki" "github"];
          engines = {
            ddg.metaData.alias = "@d";
            google.metaData.alias = "@g";
            bing.metaData.hidden = true;
            amazondotcom.metaData.hidden = true;
            ebay.metaData.hidden = true;
            wikipedia.metaData.hidden = true;
            nixos-wiki = {
              name = "NixOS Wiki";
              urls = [
                {
                  template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
                }
              ];
              definedAliases = ["@nw"];
            };
            github = {
              name = "GitHub";
              urls = [
                {
                  template = "https://github.com/search?q={searchTerms}&type=code";
                }
              ];
              definedAliases = ["@gh"];
            };
          };
        };
      };
      policies.ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
        };
        "{3e4d2037-d300-4e95-859d-3cba866f46d3}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/private-internet-access-ext/latest.xpi";
        };
      };
    };

    home.sessionVariables = {
      EDITOR = "nvim";
      MOZ_ENABLE_WAYLAND = "0";
      VISUAL = "nvim";
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
        Mod+Return { spawn "${pkgs.foot}/bin/foot"; }
        Mod+D { spawn "${pkgs.fuzzel}/bin/fuzzel"; }
        Mod+Shift+P { spawn "/home/abhay/.local/bin/power-menu"; }
        Mod+Ctrl+V { spawn "${pkgs.pavucontrol}/bin/pavucontrol"; }
        Mod+Ctrl+O { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        Mod+Ctrl+M { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
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
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }
        Mod+Shift+S { screenshot; }
        XF86AudioRaiseVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
        XF86AudioPlay { spawn "${pkgs.playerctl}/bin/playerctl" "play-pause"; }
        XF86AudioNext { spawn "${pkgs.playerctl}/bin/playerctl" "next"; }
        XF86AudioPrev { spawn "${pkgs.playerctl}/bin/playerctl" "previous"; }
        XF86MonBrightnessUp { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"; }
        XF86MonBrightnessDown { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"; }
        XF86KbdBrightnessUp { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "-d" "tpacpi::kbd_backlight" "set" "1+"; }
        XF86KbdBrightnessDown { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "-d" "tpacpi::kbd_backlight" "set" "1-"; }
        XF86Display { spawn "${pkgs.wdisplays}/bin/wdisplays"; }
        XF86WLAN { spawn-sh "case $(${pkgs.networkmanager}/bin/nmcli radio wifi) in enabled) ${pkgs.networkmanager}/bin/nmcli radio wifi off;; *) ${pkgs.networkmanager}/bin/nmcli radio wifi on;; esac"; }
        XF86Bluetooth { spawn-sh "${pkgs.bluez}/bin/bluetoothctl show | ${pkgs.gnugrep}/bin/grep -q 'Powered: yes' && ${pkgs.bluez}/bin/bluetoothctl power off || ${pkgs.bluez}/bin/bluetoothctl power on"; }
        XF86Calculator { spawn "${pkgs.gnome-calculator}/bin/gnome-calculator"; }
        XF86Tools { spawn "${pkgs.fuzzel}/bin/fuzzel"; }
      }
    '';

    xdg.configFile."waybar/config.jsonc".text = builtins.toJSON {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 4;
      modules-left = ["niri/workspaces"];
      modules-center = ["niri/window"];
      modules-right = ["network" "wireplumber" "wireplumber#source" "backlight" "battery" "clock" "custom/power" "tray"];
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
        "format-icons" = ["󰤯" "󰤟" "󰤢" "󰤥" "󰤨"];
        "tooltip-format-wifi" = "{essid} ({signalStrength}%)";
        "tooltip-format-ethernet" = "Ethernet";
      };
      wireplumber = {
        format = "{icon} {volume}%";
        "format-muted" = "󰝟 muted";
        "format-icons" = ["" "" ""];
        "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
        "on-click-middle" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "on-scroll-up" = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "on-scroll-down" = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "scroll-step" = 5;
        "tooltip-format" = "Output: {volume}%";
      };
      "wireplumber#source" = {
        "node-type" = "Audio/Source";
        format = "󰍬 {volume}%";
        "format-muted" = "󰍭 muted";
        "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
        "on-click-middle" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "on-scroll-up" = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+";
        "on-scroll-down" = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
        "scroll-step" = 5;
        "tooltip-format" = "Input: {volume}%";
      };
      backlight = {
        format = "{icon} {percent}%";
        "format-icons" = ["󰃞" "󰃟" "󰃝" "󰃠"];
        "on-scroll-up" = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        "on-scroll-down" = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
      };
      battery = {
        format = "{icon} {capacity}%";
        "format-charging" = "󰂄 {capacity}%";
        "format-plugged" = "󰚥 {capacity}%";
        "format-icons" = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        states = {
          warning = 30;
          critical = 15;
        };
        "tooltip-format" = "Battery: {capacity}% ({time})";
      };
      clock = {
        format = " {:%H:%M}";
        "tooltip-format" = "{:%A, %d %B %Y\\n%H:%M:%S}";
      };
      "custom/power" = {
        format = "";
        "tooltip" = true;
        "tooltip-format" = "Power menu";
        "on-click" = "/home/abhay/.local/bin/power-menu";
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
        color: #${kanagawa.fujiGray};
        min-width: 18px;
        padding: 0 5px;
      }

      #workspaces button.active {
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

  networking.hostName = "daredevil";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  programs.niri.enable = true;

  programs.thunar.enable = true;

  services.gvfs.enable = true;

  services.tumbler.enable = true;

  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    smc-chilanka
    smc-manjari
  ];

  security.polkit.enable = true;
  security.pam.services.swaylock = {};
  security.pam.services.greetd.enableGnomeKeyring = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;

  security.rtkit.enable = true;

  services.gnome.gnome-keyring.enable = true;

  services.fprintd.enable = true;

  services.fwupd.enable = true;

  services.tailscale.enable = true;

  services.udisks2.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  services.upower.enable = true;

  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 90;
    };
  };

  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --user abhay --cmd ${pkgs.niri}/bin/niri-session";
        user = "greeter";
      };
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["tpm_tis"];
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];
  boot.kernelParams = [
    "amd_pstate=active"
    "quiet"
    "splash"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["mode=755" "size=25%"];
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persistent".neededForBoot = true;

  systemd.suppressedSystemUnits = ["systemd-machine-id-commit.service"];

  users.users.abhay = {
    isNormalUser = true;
    description = "Abhay Prabhakaran Nair";
    extraGroups = ["wheel" "networkmanager"];
    hashedPasswordFile = config.sops.secrets."abhay-password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPgXwAtS1XN9OnFTlFoPToo2SDaNkooel5kReyOUzYT"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  sops.defaultSopsFile = ../../secrets/system-secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets."abhay-password".neededForUsers = true;

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = false;
    imports = [inputs.nixvim-config.nixvimModules.default];
    extraConfigLua = ''
      vim.opt.isfname:append("@-@")
      vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"
    '';
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    brightnessctl
    cryptsetup
    git
    htop
    fuzzel
    foot
    grim
    mako
    networkmanagerapplet
    pciutils
    playerctl
    polkit_gnome
    slurp
    swaybg
    swayidle
    swaylock
    thunar
    usbutils
    waybar
    wl-clipboard
    xwayland-satellite
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "26.05";
}
