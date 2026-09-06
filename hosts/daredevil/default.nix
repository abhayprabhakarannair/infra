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
    ./storage.nix

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/desktop"
    "${inputs.self}/modules/desktop/variables.nix"
    "${inputs.self}/modules/desktop/silentboot.nix"
    "${inputs.self}/modules/desktop/gnome.nix"
    "${inputs.self}/modules/desktop/virtualmachine.nix"
    "${inputs.self}/modules/desktop/controlroom.nix"

    "${inputs.self}/users/abhay"
  ];

  myImpermanence = {
    enable = true;
    reset = {
      enable = true;
      device = "/dev/disk/by-label/NixOS";
    };
    extraSystemDirectories = [
      "/var/lib/libvirt"
    ];
  };

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/nvme0n1";
  myStorage.swapSize = "32G";
  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
  ];

  # --- Hostname ---
  networking.hostName = "daredevil";

  networking.networkmanager.enable = true;

  # -- Boot & Kernel configurations ---
  boot = {
    kernelParams = ["amd_pstate=active"];
    kernelPackages = pkgs.linuxPackages_zen;
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

  # --- Fingerprint Authentication (Disabled for cold boot) ---
  services.fprintd.enable = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;
  security.pam.services.login.fprintAuth = false;

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
