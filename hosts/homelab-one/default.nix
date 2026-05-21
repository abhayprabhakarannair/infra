{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager

    # Absolute paths from flake root
    "${inputs.self}/users/abhay"
    "${inputs.self}/modules/server/podman.nix"

    # side config
    ./hardware-configuration.nix
  ];

  networking.hostName = "homelab-one";

  # Setup Home Manager for this specific host
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/server.nix";
  };

  system.stateVersion = "25.11";
}
