{
  pkgs,
  inputs,
  config,
  ...
}: let
  # Change this one line to select another repository wallpaper.
  wallpaperSource = ../../assets/wallpapers/anime_axe_viking.png;
  wallpaperPath = "${config.home.homeDirectory}/.local/share/backgrounds/current-wallpaper";
in {
  imports = ["${inputs.self}/home/desktop"];

  # --- Essential apps ---
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
  ];

  # Keep the selected wallpaper in the repository behind a stable path so
  # changing wallpapers only requires editing wallpaperSource above.
  home.file.".local/share/backgrounds/current-wallpaper".source = wallpaperSource;

  # --- Modern UI Fonts & Rendering ---
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
