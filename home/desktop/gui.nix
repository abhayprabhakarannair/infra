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
    pi-coding-agent
    pkgs.llm-agents.chatgpt
    deploy-rs
    gh
    inter
    zed-editor
    nil
    nixd
    nixpkgs-fmt
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

  # --- WezTerm ---
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wez = require('wezterm')
      local config = wez.config_builder()

      config.font = wez.font('JetBrainsMono Nerd Font', { weight = 'Medium' })
      config.font_size = 13.0
      config.color_scheme = 'Kanagawa (Gogh)'
      config.window_padding = { left = 8, right = 8, top = 8, bottom = 8 }
      config.enable_tab_bar = false
      config.hide_mouse_cursor_when_typing = true

      return config
    '';
  };

  programs.vivaldi = {
    enable = true;
    # Vivaldi is installed by the desktop NixOS module; Home Manager manages
    # its profile and extensions here.
    package = null;
    extensions = [
      # uBlock Origin
      {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";}
      # Private Internet Access (PIA) Extension
      {id = "jplnlifepflhkbkgonidnobkakhmpnmh";}
      # Official ChatGPT browser integration for Codex
      {id = "hehggadaopoacecdllhhajmbjkdcmajg";}
    ];
  };
}
