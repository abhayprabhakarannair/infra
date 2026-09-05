{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os_server.nix"
    ./storage.nix

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/server/podman.nix"
    "${inputs.self}/modules/desktop/controlroom.nix"
    "${inputs.self}/modules/services/omada-controller.nix"
    "${inputs.self}/modules/services/technitium.nix"
    "${inputs.self}/modules/services/net-ups-client.nix"
    "${inputs.self}/modules/services/home-assistant.nix"

    "${inputs.self}/users/abhay"
  ];

  myImpermanence = {
    enable = true;
    serviceDirectories = [
      "/srv/home-assistant"
      "/srv/omada-controller"
      "/srv/technitium"
    ];
  };

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/sda";

  # --- Hostname ---
  networking.hostName = "old-devil";

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
    kernelParams = ["consoleblank=60"];
    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 15;
        consoleMode = "max";
      };
    };
  };

  # --- Power Management (Prevent Sleep & Ignore Lid) ---
  services.logind.settings = {
    Login = {
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitch = "ignore";
    };
  };

  # --- Completely disable sleep, suspend, and hibernate targets ---
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # --- This is the Networking hub device ---
  networking.firewall.allowedUDPPorts = [
    config.services.tailscale.port
    19810
    27001
    29810
    53
    9
  ];
  networking.firewall.allowedTCPPorts = [
    2442
    80
    443
    8043
    8088
    8843
    29811
    29812
    29813
    29814
    29815
    29816
    29817
    8085
    53
  ];

  # Temp
  systemd.services.wol-relay = {
    description = "Wake-on-LAN UDP Relay (Tailscale to Physical LAN)";
    after = ["network-online.target" "tailscaled.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.socat}/bin/socat UDP4-LISTEN:9,fork UDP4-DATAGRAM:192.168.0.255:9,broadcast";
      Restart = "always";
      RestartSec = "10s";
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

  # --- State Version ---
  system.stateVersion = "26.05";
}
