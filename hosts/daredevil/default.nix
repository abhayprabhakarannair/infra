{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager

    ./hardware.nix
    "${inputs.self}/hosts/shared/disko_os.nix"

    "${inputs.self}/modules/core"
    "${inputs.self}/modules/desktop"
    "${inputs.self}/modules/desktop/silentboot.nix"
    "${inputs.self}/modules/desktop/environment.nix"

    "${inputs.self}/users/abhay"
  ];

  # --- Default Drive ---
  disko.devices.disk.main.device = "/dev/nvme0n1";
  myStorage.swapSize = "32G";

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

  # --- Fingerprint (Disabled for login) ---
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = false;
  security.pam.services.kde.fprintAuth = pkgs.lib.mkForce true;

  # --- Enable Home Manager ---
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    users.abhay = import "${inputs.self}/home/desktop/gui.nix";
  };

  # --- State Version ---
  system.stateVersion = "25.11";
}
