{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;
  imports = [../../modules/base.nix ../../modules/niri.nix ../../modules/persistence.nix ../../modules/laptop.nix];
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelModules = ["tun" "amdgpu"];
  boot.kernelParams = ["amd_pstate=active"];
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = "magic";
  systemd.tmpfiles.rules = ["d /mnt/games 0755 abhay users -"];
}
