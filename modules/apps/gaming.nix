{pkgs, ...}: {
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = [pkgs.proton-ge-bin];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  environment.systemPackages = with pkgs; [
    gamescope-wsi
    goverlay
    mangohud
    pulseaudio
  ];

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  boot.initrd.kernelModules = ["amdgpu"];
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;
}
