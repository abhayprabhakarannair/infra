{
  description = "Minimal NixOS foundation for daredevil";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    preservation.url = "github:nix-community/preservation";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    disko,
    home-manager,
    preservation,
    sops-nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    nixosConfigurations.daredevil = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        preservation.nixosModules.preservation
        sops-nix.nixosModules.sops
        ./hosts/daredevil
      ];
    };

    packages.${system}.install-infra = pkgs.writeShellApplication {
      name = "install-infra";
      runtimeInputs = [pkgs.nixos-anywhere pkgs.openssh pkgs.coreutils];
      text = builtins.readFile ./scripts/install-infra.sh;
    };

    apps.${system}.install-infra = {
      type = "app";
      program = "${self.packages.${system}.install-infra}/bin/install-infra";
    };
  };
}
