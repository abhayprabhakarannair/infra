{
  inputs,
  kanagawa,
  pkgs,
  ...
}:
{
  programs.thunar.enable = true;

  home-manager.users.abhay = {
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

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };

    home.activation.seedZedSettings = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      zedSettings="$HOME/.config/zed/settings.json"
      if [ -L "$zedSettings" ] && [[ "$(readlink "$zedSettings")" == /nix/store/* ]]; then
        rm "$zedSettings"
      fi
      if [ ! -e "$zedSettings" ]; then
        install -Dm644 ${
          pkgs.writeText "zed-settings.json" (
            builtins.toJSON {
              theme = "Kanagawa";
              vim_mode = true;
              buffer_font_family = "JetBrains Mono";
              buffer_font_size = 15;
              ui_font_family = "Inter";
              ui_font_size = 14;
              autosave = "on_focus_change";
              format_on_save = "on";
              terminal = {
                font_family = "JetBrains Mono";
                font_size = 13;
                shell = {
                  program = "bash";
                };
              };
            }
          )
        } "$zedSettings"
      fi
    '';

    home.file.".local/bin/toggle-microphone" = {
      executable = true;
      text = ''
        #!/bin/sh
        set -eu

        wpctl="${pkgs.wireplumber}/bin/wpctl"
        source="@DEFAULT_AUDIO_SOURCE@"
        "$wpctl" get-volume "$source" >/dev/null
        exec "$wpctl" set-mute "$source" toggle
      '';
    };

    gtk = {
      enable = true;
      colorScheme = "dark";
      iconTheme = {
        name = "Tela-dark";
        package = pkgs.tela-icon-theme;
      };
      theme = {
        name = "Kanagawa";
        package = pkgs.kanagawa-gtk-theme;
      };
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk3.extraConfig.gtk-theme-name = "Kanagawa";
      gtk3.extraConfig.gtk-icon-theme-name = "Tela-dark";
      gtk4.extraConfig.gtk-theme-name = "Kanagawa";
      gtk4.extraConfig.gtk-icon-theme-name = "Tela-dark";
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk3";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        document-font-name = "Inter 11";
        font-name = "Inter 11";
        gtk-theme = "Kanagawa";
        icon-theme = "Tela-dark";
        monospace-font-name = "JetBrainsMono Nerd Font Mono 11";
      };
    };

    home.sessionVariables = {
      ADW_DEBUG_COLOR_SCHEME = "prefer-dark";
      EDITOR = "nvim";
      GTK_THEME = "Kanagawa";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_STYLE_OVERRIDE = "adwaita-dark";
      VISUAL = "nvim";
    };

  };
}
