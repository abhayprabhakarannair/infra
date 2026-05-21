{
  description = "Abhay's Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    ...
  } @ inputs: let
    # --- Default username & WSL host ---
    username = "abhay";
    wslHostname = "ANair-1082";

    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # --- THE OVERLAY (Unstable and custom packages w/non-free) ---
    systemOverlay = final: prev: {
      unstable = import nixpkgs-unstable {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };

      install-infra = final.callPackage ./pkgs/install-infra {};
    };
    globalConfig = {
      nixpkgs.overlays = [systemOverlay];
      nixpkgs.config.allowUnfree = true;
    };
  in {
    # --- CUSTOM PACKAGES EXPORT ---
    # Makes `nix run .#install-infra` work on any architecture
    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
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
    };

    # --- WSL STANDALONE CONFIG ---
    homeConfigurations = {
      "${username}@${wslHostname}" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [systemOverlay];
        };
        extraSpecialArgs = {inherit inputs;};
        modules = [./home/desktop/wsl.nix];
      };
    };
  };
}
