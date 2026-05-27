{pkgs, ...}: {
  # --- Enable Gnome & GDM ---
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.enable = false;

  # --- Remove initial bloat ---
  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;

  # --- Setup basic stuffs ---
  programs.seahorse.enable = true;
  programs.gnome-disks.enable = true;
  services.gnome.sushi.enable = true;
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  # --- Keyring Setup ---
  services.gnome.gnome-keyring.enable = true;

  # --- System packages ---
  environment.systemPackages = with pkgs; [
    vivaldi
    gnome-browser-connector
    ptyxis

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
  ];

  # --- Exclude GNOME defaults ---
  environment.gnome.excludePackages = with pkgs; [
    gnome-console
    gnome-terminal
  ];

  # --- System wide envs ---
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
