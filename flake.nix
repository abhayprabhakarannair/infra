{
  description = "Abhay's Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    sops-nix,
    wrappers,
    nixvim,
    ...
  } @ inputs: let
    # --- Default username & WSL host ---
    username = "abhay";
    wslHostname = "ANair-1082";

    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # --- SHARED NIXPKGS CONFIGURATION ---
    sharedConfig = {
      allowUnfree = true;
    };

    # --- THE OVERLAY (Unstable and custom packages w/non-free) ---
    systemOverlay = final: prev: {
      unstable = import nixpkgs-unstable {
        system = prev.stdenv.hostPlatform.system;
        config = sharedConfig;
      };

      install-infra = final.callPackage ./pkgs/install-infra {};
    };
    globalConfig = {
      nixpkgs.overlays = [systemOverlay];
      nixpkgs.config = sharedConfig;
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
  in {
    # --- CUSTOM PACKAGES EXPORT ---
    # Makes `nix run .#install-infra` work on any architecture
    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = sharedConfig;
          overlays = [systemOverlay];
        };
      in {
        inherit (pkgs) install-infra;
      }
    );

    # --- NIXOS CONFIGURATIONS ---
    nixosConfigurations = {
      # ThinkPad
      daredevil = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          globalConfig
          ./hosts/daredevil/default.nix
        ];
      };

      # Gaming PC
      devil = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          globalConfig
          ./hosts/devil/default.nix
        ];
      };

      # Old Laptop
      old-devil = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          globalConfig
          ./hosts/old-devil/default.nix
        ];
      };

      # Homelab One (Hetzner alpha node)
      homelab-one = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          globalConfig
          ./hosts/homelab-one/default.nix
        ];
      };
    };

    # --- WSL STANDALONE CONFIG ---
    homeConfigurations = {
      "${username}@${wslHostname}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config = sharedConfig;
          overlays = [systemOverlay];
        };
        extraSpecialArgs = {inherit inputs;};
        modules = [./home/wsl.nix];
      };
    };
  };
}
