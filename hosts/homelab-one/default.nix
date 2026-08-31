{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os_server_bios.nix"
    ./storage.nix

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/server/podman.nix"

    "${inputs.self}/modules/services/caddy.nix"
    "${inputs.self}/modules/services/vaultwarden.nix"
    "${inputs.self}/modules/services/forgejo.nix"
    "${inputs.self}/modules/services/forgejo-runner.nix"
    "${inputs.self}/modules/services/grafana"
    "${inputs.self}/modules/services/grafana/alloy-hub.nix"

    "${inputs.self}/users/abhay"
  ];

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/sda";

  # --- Hostname ---
  networking.hostName = "homelab-one";

  # --- Networking ---
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  networking.enableIPv6 = true;
  networking.firewall.allowedTCPPorts = [
    2442
    80
    443
    2222
  ];

  # --- WAN (Public Internet Interface) ---
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";

    address = ["2a01:4f8:c013:bfc8::1/64"];
    routes = [{Gateway = "fe80::1";}];

    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
      IPv4Forwarding = true;
      IPv6Forwarding = true;
      IPMasquerade = "both";
    };
  };

  # --- LAN (Hetzner Private Network Interface) ---
  systemd.network.networks."20-lan" = {
    matchConfig.Name = "enp7s0";

    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
  };

  # -- Boot & Kernel configurations ---
  boot = {
    kernelModules = ["tcp_bbr"];
    kernelPackages = pkgs.linuxPackages;

    kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    loader = {
      systemd-boot.enable = false;

      grub = {
        enable = true;
        configurationLimit = 5;
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

  # --- Tighter GC: small disk (39G), keep less history ---
  nix.gc.options = lib.mkForce "--delete-older-than 7d";

  # --- Enable QEMU Guest Agent (Hetzner Controls) ---
  services.qemuGuest.enable = true;

  # --- State Version ---
  system.stateVersion = "26.05";
}
