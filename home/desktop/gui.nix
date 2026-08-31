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

  # --- Modern UI Fonts & Rendering ---
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      font-name = "Inter 11";
      document-font-name = "Inter 11";
      monospace-font-name = "JetBrainsMono Nerd Font 10";
      font-antialiasing = "grayscale";
      font-hinting = "slight";
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

  programs.chromium = {
    enable = true;
    package = pkgs.unstable.brave;
    extensions = [
      # uBlock Origin
      {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";}
      # Private Internet Access (PIA) Extension
      {id = "jplnlifepflhkbkgonidnobkakhmpnmh";}
    ];
  };
}
