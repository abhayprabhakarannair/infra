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

}
