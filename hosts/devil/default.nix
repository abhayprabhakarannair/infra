{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os_encrypted.nix"
    ./disko_games.nix
    ./storage.nix

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/desktop"
    "${inputs.self}/modules/desktop/variables.nix"
    "${inputs.self}/modules/desktop/silentboot.nix"
    "${inputs.self}/modules/desktop/gnome.nix"
    "${inputs.self}/modules/desktop/gaming.nix"
    "${inputs.self}/modules/desktop/virtualmachine.nix"
    "${inputs.self}/modules/desktop/controlroom.nix"

    "${inputs.self}/modules/services/jellyfin.nix"
    "${inputs.self}/modules/services/stash.nix"
    "${inputs.self}/modules/services/arr-stack.nix"
    "${inputs.self}/modules/services/media-warm.nix"
    "${inputs.self}/modules/services/immich.nix"
    "${inputs.self}/modules/services/ollama.nix"
    "${inputs.self}/modules/services/net-ups-server.nix"

    "${inputs.self}/users/abhay"
  ];

  myImpermanence = {
    enable = true;
    reset = {
      enable = true;
      device = "/dev/mapper/enc";
    };
    serviceDirectories = [
      "/srv/jellyfin"
      "/srv/immich/postgres"
      "/srv/prowlarr"
      "/srv/sonarr"
      "/srv/radarr"
      "/srv/sabnzbd"
      "/srv/downloads"
      "/srv/whisparr"
      "/srv/gluetun"
      "/srv/qbittorrent"
      "/srv/seerr"
      "/srv/stash"
    ];
    homeDirectories = [
      "Sync"
      "Projects"
      "Pictures"
      "Documents"
      "Downloads"
      ".config/syncthing"
      ".config/vivaldi"
      ".config/obsidian"
      ".config/Codex"
      ".config/opencode"
      ".config/dconf"
      ".local/share/keyrings"
      ".local/share/backgrounds"
      ".local/share/icons"
      ".local/share/Steam/userdata"
      ".local/state/nix"
      ".ssh"
      ".codex"
    ];
  };

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/nvme1n1";
  disko.devices.disk.games.device = "/dev/nvme0n1";
  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
    "d /mnt/games 0755 abhay users - -"
  ];
  myStorage.swapSize = "32G";

  # --- Hostname ---
  networking.hostName = "devil";

  # --- Networking & Wake on LAN ---
  networking.interfaces.enp14s0.wakeOnLan.enable = true;
  networking.networkmanager = {
    enable = true;
    settings = {
      connection = {
        "ethernet.wake-on-lan" = "magic";
      };
    };
  };

  # -- Boot & Kernel configurations ---
  boot = {
    kernelModules = ["tcp_bbr"];
    kernelParams = ["amd_pstate=active"];
    kernelPackages = pkgs.linuxPackages_zen;

    kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    loader = {
      efi.canTouchEfiVariables = true;

      systemd-boot = {
        enable = true;
        configurationLimit = 15;
        consoleMode = "max";
      };
    };

    # Needed for tpm2 to work properly with my encryption
    initrd = {
      systemd.enable = true;
      kernelModules = ["amdgpu"];
      availableKernelModules = ["tpm_tis"];
      luks.devices."enc".crypttabExtraOpts = ["tpm2-device=auto"];
    };
  };

  # --- File system & cleanups ---
  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
  };
  services.udisks2.enable = true;

  # --- Enable Home Manager ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/desktop/gui.nix";
  };

  # --- State Version ---
  system.stateVersion = "26.05";
}
