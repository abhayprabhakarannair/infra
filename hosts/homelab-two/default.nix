{pkgs, inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os_server_bios.nix"

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/core/storage.nix"
    "${inputs.self}/modules/server/podman.nix"
    "${inputs.self}/modules/containers/jellyfin"


    "${inputs.self}/users/abhay"
  ];

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/vda";

  # --- Hostname ---
  networking.hostName = "homelab-two";

  # --- Networking ---
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  networking.enableIPv6 = false;

  systemd.network.networks."10-ethernet-catchall" = {
    matchConfig.Name = "en* eth*";
    networkConfig = {
      DHCP = "yes";
      IPv4Forwarding = "yes";
      IPv6Forwarding = "yes";
      IPMasquerade = "both";
    };
  };

  # -- Boot & Kernel configurations ---
  boot = {
    kernelPackages = pkgs.linuxPackages;

    loader = {
      systemd-boot.enable = false;

      grub = {
        enable = true;
      };
    };
  };

  # --- File system & cleanups ---
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };


  # --- Enable Home Manager ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/server.nix";
  };

  # --- Enable QEMU Guest Agent (Hetzner Controls) ---
  services.qemuGuest.enable = true;

  # --- State Version ---
  system.stateVersion = "26.05";
}
