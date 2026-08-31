{
  description = "Abhay's Infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";

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

    nixvim = {
      url = "github:nix-community/nixvim";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim-config = {
      url = "git+https://git.iamabhay.fyi/abhay/nixvim-config.git";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    sops-nix,
    nixvim,
    deploy-rs,
    nixvim-config,
    ...
  } @ inputs: let
    # --- Default username ---
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
        overlays = [];
      };

      llm-agents = (inputs.llm-agents.overlays.shared-nixpkgs final prev).llm-agents;

      install-infra = final.callPackage ./pkgs/install-infra {};
      herdr = final.callPackage ./pkgs/herdr {};
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
        deploy-rs = pkgs.deploy-rs;
      }
    );

    # --- APPS ---
    apps = forAllSystems (system: {
      deploy = {
        type = "app";
        program = "${self.packages.${system}.deploy-rs}/bin/deploy";
        meta.description = "Deploy NixOS configurations with auto-rollback";
      };
    });

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

    # --- DEPLOYMENTS ---
    deploy.nodes = {
      daredevil = {
        hostname = "daredevil";
        sshUser = "root";
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.daredevil;
        };
      };

      devil = {
        hostname = "devil";
        sshUser = "root";
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.devil;
        };
      };

      old-devil = {
        hostname = "old-devil";
        sshUser = "root";
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.old-devil;
        };
      };

      homelab-one = {
        hostname = "homelab-one";
        sshUser = "root";
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.homelab-one;
        };
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
  };
}
