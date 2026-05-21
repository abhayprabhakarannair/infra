{pkgs, ...}: {
  # --- Swapping to a lightweight DM ---
  services.displayManager.sddm.enable = false;
  services.displayManager.ly.enable = true;
  services.displayManager.defaultSession = "plasma";

  # --- Fix PAM and stuffs ---
  security.pam.services.ly.kwallet = {
    enable = true;
    package = pkgs.kdePackages.kwallet-pam;
  };

  # --- Enable KDE ---
  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = false;

  # System packages
  environment.systemPackages = with pkgs; [
    kdePackages.bluedevil
    kdePackages.plasma-browser-integration
  ];
}
