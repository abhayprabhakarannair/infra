{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ./hardware.nix
    "${inputs.self}/users/abhay"
    "${inputs.self}/modules/server/podman.nix"

  ];

  networking.hostName = "homelab-one";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/server.nix";
  };

  system.stateVersion = "26.05";
}
