{
  pkgs,
  inputs,
  config,
  ...
}: let
  wallpaperPath = "${config.home.homeDirectory}/.local/share/backgrounds/current-wallpaper";
  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = [pkgs.coreutils pkgs.glib];
    text = ''
      set -euo pipefail

      if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
        echo "Usage: set-wallpaper IMAGE" >&2
        exit 1
      fi

      destination="$HOME/.local/share/backgrounds/current-wallpaper"
      mkdir -p "$(dirname "$destination")"
      install -m 0644 "$1" "$destination"
      gsettings set org.gnome.desktop.background picture-uri "file://$destination"
      gsettings set org.gnome.desktop.background picture-uri-dark "file://$destination"
    '';
  };
in {
  imports = ["${inputs.self}/home/desktop"];

  home.packages = with pkgs.unstable; [
    vlc
    fastfetch
    wl-clipboard
    tela-icon-theme
    nodejs_24
    python314
    pkgs.llm-agents.chatgpt
    deploy-rs
    gh
    inter
    zed-editor
    nil
    nixd
    setWallpaper
  ];

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      font-name = "Inter 11";
      document-font-name = "Inter 11";
      monospace-font-name = "JetBrainsMono Nerd Font 10";
      font-antialiasing = "grayscale";
      font-hinting = "slight";
      icon-theme = "Tela-dark";
    };

    "org/gnome/desktop/background" = {
      color-shading-type = "solid";
      picture-options = "zoom";
      picture-uri = "file://${wallpaperPath}";
      picture-uri-dark = "file://${wallpaperPath}";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };
  };
}
