{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.self}/home/desktop"];

  # --- Essential apps ---
  home.packages = with pkgs.unstable; [
    bitwarden-desktop
    vlc
    fastfetch
    neovim
    wl-clipboard
  ];
}
