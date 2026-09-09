{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;
  imports = [../../modules/base.nix ../../modules/niri.nix ../../modules/persistence.nix];
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelModules = ["tun" "amdgpu"];
  boot.kernelParams = ["amd_pstate=active"];
  # Devil must be able to finish booting after remote Wake-on-LAN without a
  # passphrase at the local console. The TPM slot is enrolled by
  # scripts/after-install.sh after the first boot.
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["tpm_tis"];
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];
  networking.interfaces.enp14s0.wakeOnLan.enable = true;
  networking.networkmanager.settings.connection."ethernet.wake-on-lan" = "magic";
  systemd.tmpfiles.rules = ["d /mnt/games 0755 abhay users -"];
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
