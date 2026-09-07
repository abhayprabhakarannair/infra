{pkgs, ...}: {
  # --- Enable Gnome & GDM ---
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.enable = false;

  # --- Autologin Configuration ---
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "abhay";

  # --- Keyring fix for gnome autologin ---
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;
  systemd.user.services.gnome-keyring-daemon = {
    wantedBy = ["default.target"];
  };

  # --- Remove initial bloat ---
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;

  # --- Setup basic stuffs ---
  programs.dconf.enable = true;
  programs.seahorse.enable = true;
  programs.gnome-disks.enable = true;
  services.gnome.sushi.enable = true;
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # --- System packages ---
  environment.systemPackages = with pkgs; [
    ptyxis
    vivaldi
    gnome-browser-connector

    # --- GNOME Essentials ---
    nautilus
    file-roller
    gnome-tweaks
    gnome-extension-manager

    # --- Screenshot & Annotation ---
    gradia

    # --- Basic Media Viewers ---
    loupe
    evince
    gnome-text-editor
    gnome-calculator

    # --- Extra Apps ---
    unstable.obsidian
  ];

  # --- Exclude GNOME defaults ---
  environment.gnome.excludePackages = with pkgs; [
    gnome-console
    gnome-terminal
  ];
}
