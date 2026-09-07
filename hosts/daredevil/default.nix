{
  networking.hostName = "daredevil";

  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
    ../../modules/base.nix
    ../../modules/laptop.nix
    ../../modules/niri.nix
    ../../modules/persistence.nix
    ../../modules/podman.nix
    ../../modules/desktop.nix
  ];
}
