{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.self}/home/desktop"];

  # --- Essential apps ---
  home.packages = with pkgs.unstable; [
    vlc
    fastfetch
    wl-clipboard
    tela-icon-theme
  ];


  programs.chromium = {
    enable = true;
    package = pkgs.unstable.brave;
    extensions = [
      # uBlock Origin
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } 
      # Private Internet Access (PIA) Extension
      { id = "jplnlifepflhkbkgonidnobkakhmpnmh"; } 
    ];
  };

}
