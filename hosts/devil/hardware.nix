# Generated hardware baseline migrated from legacy Devil.
{config, lib, modulesPath, ...}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];
  boot.initrd.availableKernelModules = ["nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod"];
  boot.kernelModules = ["kvm-amd"];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
