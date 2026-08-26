{
  pkgs,
  lib,
  inputs,
  ...
}: let
  devices = import "${inputs.self}/modules/syncthing/devices.nix";
in {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os_server_bios.nix"

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/server/podman.nix"
    "${inputs.self}/modules/services/hermes-agent.nix"

    "${inputs.self}/users/abhay"
  ];

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/vda";

  # --- Hostname ---
  networking.hostName = "lucifer";

  # --- Networking (Rabisu VPS: single static-IPv4 NIC, no private LAN) ---
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  networking.enableIPv6 = false;

  # No inbound web/API surface by design — outbound-only Telegram/Discord
  # polling needs zero open ports. SSH only (port set in modules/core).
  networking.firewall.allowedTCPPorts = [];

  # NOTE: matched by glob, not a literal name — virtio NIC naming (ens18/enp0s18/etc.)
  # is not guaranteed stable across reinstalls; this box only ever has one NIC.
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "en*";
    address = ["185.255.94.169/24"];
    routes = [{routeConfig.Gateway = "185.255.94.1";}];
    networkConfig.DHCP = "no";
    linkConfig.MTUBytes = "1436";
  };

  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  # --- Syncthing Service for Hermes Agent Live Vault ---
  services.syncthing = {
    enable = true;
    user = "hermes";
    dataDir = "/srv/hermes/Sync";
    configDir = "/srv/hermes/.config/syncthing";
    guiAddress = "127.0.0.1:8384";
    overrideDevices = false;
    overrideFolders = false;
    settings = {
      devices = {
        "daredevil" = {id = devices.daredevil;};
        "devil" = {id = devices.devil;};
        "old-devil" = {id = devices.oldDevil;};
        "oneplus-13" = {id = devices.oneplus13;};
      };
      folders = {
        "Lucifer" = {
          path = "/srv/hermes/Sync/Lucifer";
          devices = ["daredevil" "devil" "old-devil" "oneplus-13"];
        };
      };
    };
  };

  # -- Boot & Kernel configurations (BIOS/legacy, per Phase 1 discovery) ---
  boot = {
    kernelPackages = pkgs.linuxPackages;
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        configurationLimit = 5;
      };
    };
  };

  # --- Enable Home Manager ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/server.nix";
    users.hermes = import "${inputs.self}/home/hermes.nix";
  };

  # --- Tighter GC: small disk (40G), keep less history (matches homelab-one) ---
  nix.gc.options = lib.mkForce "--delete-older-than 7d";

  # --- State Version ---
  system.stateVersion = "26.05";
}
