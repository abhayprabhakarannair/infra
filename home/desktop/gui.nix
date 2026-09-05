{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.self}/home/desktop"];

  # --- Essential apps ---
  home.packages = with pkgs.unstable; [
    vlc
    discord
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

  # Keep the selected wallpaper in the repository so a reset rebuilds it,
  # rather than relying on an opaque copy in the persisted home tree.
  home.file.".local/share/backgrounds/anime_axe_viking.png".source =
    ../../assets/wallpapers/anime_axe_viking.png;

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
      picture-uri = "file:///home/abhay/.local/share/backgrounds/anime_axe_viking.png";
      picture-uri-dark = "file:///home/abhay/.local/share/backgrounds/anime_axe_viking.png";
      primary-color = "#000000000000";
      secondary-color = "#000000000000";
    };
  };

}
