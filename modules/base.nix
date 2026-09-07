{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  programs.thunar.enable = true;

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
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
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

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = false;
    imports = [inputs.nixvim-config.nixvimModules.default];
    extraConfigLua = ''
      vim.opt.isfname:append("@-@")
      vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"
    '';
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    brightnessctl
    cryptsetup
    git
    htop
    fuzzel
    foot
    grim
    mako
    networkmanagerapplet
    pciutils
    playerctl
    polkit_gnome
    slurp
    swaybg
    swayidle
    swaylock
    thunar
    usbutils
    waybar
    wl-clipboard
    xwayland-satellite
    xdg-utils
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  system.stateVersion = "26.05";
}
