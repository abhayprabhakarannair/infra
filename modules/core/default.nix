{pkgs, ...}: {
  # --- Timezone and Locale ---
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Essential System Packages ---
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    jq
  ];

  # --- ZSH across all ---
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # --- SSH ---
  services.openssh = {
    enable = true;
    ports = [2442];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users."root".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
  ];

  # --- Firewall ---
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [2442 80 443];
    allowedUDPPorts = [3478];
  };

  # --- Logging Constraints ---
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemMaxFileSize=200M
  '';

  # --- NixOS common configurations ---
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
}
