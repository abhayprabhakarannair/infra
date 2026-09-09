{...}: {
  networking.hostName = "devil";
  _module.args.niriHardwareBindings = "";

  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
    ./system.nix
    ./apps.nix
    ./services.nix
  ];
}
