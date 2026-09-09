{
  description = "Declarative NixOS infrastructure for Daredevil and Devil";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
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

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim-config = {
      url = "github:abhayprabhakarannair/nixvim-config";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    disko,
    deploy-rs,
    home-manager,
    nixvim,
    preservation,
    sops-nix,
    nixvim-config,
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
        nixvim.nixosModules.nixvim
        preservation.nixosModules.preservation
        sops-nix.nixosModules.sops
        ./hosts/daredevil
      ];
    };

    nixosConfigurations.devil = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        nixvim.nixosModules.nixvim
        preservation.nixosModules.preservation
        sops-nix.nixosModules.sops
        ./hosts/devil
      ];
    };

    packages.${system}.install-infra = pkgs.writeShellApplication {
      name = "install-infra";
      runtimeInputs = [pkgs.nixos-anywhere pkgs.openssh pkgs.coreutils];
      text = builtins.readFile ./scripts/install-infra.sh;
    };

    apps.${system} = {
      install-infra = {
        type = "app";
        program = "${self.packages.${system}.install-infra}/bin/install-infra";
      };

      deploy = {
        type = "app";
        program = "${deploy-rs.packages.${system}.deploy-rs}/bin/deploy";
      };
    };

    deploy.nodes.daredevil = {
      hostname = "192.168.0.16";
      sshOpts = ["-p" "2442"];
      profiles.system = {
        sshUser = "abhay";
        user = "root";
        interactiveSudo = true;
        remoteBuild = true;
        fastConnection = false;
        autoRollback = true;
        magicRollback = false;
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.daredevil;
      };
    };

    deploy.nodes.devil = {
      hostname = "devil";
      sshOpts = ["-p" "2442"];
      profiles.system = {
        sshUser = "abhay";
        user = "root";
        interactiveSudo = true;
        remoteBuild = true;
        fastConnection = false;
        autoRollback = true;
        magicRollback = false;
        path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.devil;
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
