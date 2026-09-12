{
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  services.gvfs.enable = true;

  services.tumbler.enable = true;

  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    smc-chilanka
    smc-manjari
  ];

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  security.rtkit.enable = true;

  services.gnome.gnome-keyring.enable = true;

  services.fprintd.enable = true;

  services.fwupd.enable = true;

  services.tailscale.enable = true;

  services.udisks2.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  services.upower.enable = true;

  services.power-profiles-daemon.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      glibc
      libffi
    ];
  };

  system.stateVersion = "26.05";
}
