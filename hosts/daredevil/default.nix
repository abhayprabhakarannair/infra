{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
  ];

  home-manager.users.abhay = {
    home.username = "abhay";
    home.homeDirectory = "/home/abhay";
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
    programs.bash.enable = true;
  };

  networking.hostName = "daredevil";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["tpm_tis"];
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["mode=755" "size=25%"];
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persistent".neededForBoot = true;

  systemd.suppressedSystemUnits = ["systemd-machine-id-commit.service"];

  users.users.abhay = {
    isNormalUser = true;
    description = "Abhay Prabhakaran Nair";
    extraGroups = ["wheel" "networkmanager"];
    hashedPasswordFile = config.sops.secrets."abhay-password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPgXwAtS1XN9OnFTlFoPToo2SDaNkooel5kReyOUzYT"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  sops.defaultSopsFile = ../../secrets/system-secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets."abhay-password".neededForUsers = true;

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cryptsetup
    git
    htop
    pciutils
    usbutils
    vim
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  system.stateVersion = "26.05";
}
