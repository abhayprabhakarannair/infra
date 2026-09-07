{pkgs, ...}: {
  programs.steam = {
    enable = true;
    package = pkgs.unstable.steam;

    gamescopeSession = {
      enable = true;
    };

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;

    extraCompatPackages = with pkgs.unstable; [
      proton-ge-bin
    ];
  };

  environment.systemPackages = with pkgs.unstable; [
    mangohud
    goverlay
    gamescope-wsi
  ];

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  # Crucial Kernel tweak: Prevents heavy memory-intensive games (like Cyberpunk 2077 or massive open-world titles)
  # from crashing due to running out of default memory map handles.
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    package = pkgs.unstable.mesa;
    package32 = pkgs.unstable.pkgsi686Linux.mesa;
  };
}
