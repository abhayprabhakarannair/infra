{pkgs, ...}: {
  # --- Enable KDE ---
  services.desktopManager.plasma6.enable = true;
  services.displayManager.plasma-login-manager.enable = true;
  services.xserver.enable = false;

  # --- System packages ---
  environment.systemPackages = with pkgs; [
    vivaldi
    kdePackages.bluedevil
    kdePackages.plasma-browser-integration
  ];

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole
  ];

  # --- KDE connection ---
  programs.chromium = {
    enable = true;
    enablePlasmaBrowserIntegration = true;
  };
}
