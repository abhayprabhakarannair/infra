{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.self}/home/desktop"];

  # --- Essential apps ---
  home.packages = with pkgs.unstable; [
    (vivaldi.override {
      enableWidevine = true;
      proprietaryCodecs = true;
      commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
    })
    bitwarden-desktop
    vlc
    fastfetch
    neovim
    wl-clipboard
  ];

  # --- Fix vivaldi to KDE bridge ---
  home.file.".config/vivaldi/NativeMessagingHosts/org.kde.plasma.browser_integration.json".source = "${pkgs.kdePackages.plasma-browser-integration}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
}
