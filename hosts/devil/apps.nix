{pkgs, ...}: {
  imports = [../../modules/apps/theme.nix ../../modules/apps/terminal.nix ../../modules/apps/development.nix ../../modules/apps/desktop-core.nix ../../modules/apps/browsers.nix ../../modules/apps/wayland-ui.nix];
  environment.systemPackages = with pkgs; [btrfs-progs brightnessctl fuzzel foot grim mako playerctl slurp swaybg swayidle swaylock thunar waybar wl-clipboard xwayland-satellite];
  home-manager.users.abhay.home.packages = with pkgs; [age fastfetch git gh jq steam lutris mangohud protonup-qt sops vlc wdisplays];
  programs.steam.enable = true;
}
