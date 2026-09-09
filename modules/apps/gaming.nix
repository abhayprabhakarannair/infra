{pkgs, unstablePkgs, ...}: {
  programs.steam = {
    enable = true;
    package = unstablePkgs.steam;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = [unstablePkgs.proton-ge-bin];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  environment.systemPackages = [
    unstablePkgs.gamescope-wsi
    unstablePkgs.goverlay
    unstablePkgs.mangohud
    pkgs.pulseaudio
  ];

  home-manager.users.abhay.xdg.desktopEntries.steam = {
    name = "Steam";
    genericName = "Game platform";
    comment = "Steam with native Wayland rendering";
    exec = "steam -cef-disable-gpu --enable-features=UseOzonePlatform --ozone-platform=wayland %U";
    icon = "steam";
    terminal = false;
    type = "Application";
    categories = ["Game"];
    mimeType = ["x-scheme-handler/steam"];
    startupNotify = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    package = unstablePkgs.mesa;
    package32 = unstablePkgs.pkgsi686Linux.mesa;
  };
  boot.initrd.kernelModules = ["amdgpu"];
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
