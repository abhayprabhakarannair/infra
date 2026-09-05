{
  pkgs,
  inputs,
  config,
  ...
}: {
  imports = [
    ../impermanence
  ];

  # Tailscale and the Gluetun VPN container both require the kernel TUN device.
  boot.kernelModules = ["tun"];

  # --- Timezone and Locale ---
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  # --- Essential System Packages ---
  environment.systemPackages = with pkgs; [
    wget
    curl
    rclone
    wakeonlan
    ethtool
  ];

  # --- Secrets ---
  sops.defaultSopsFile = "${inputs.self}/secrets/system-secrets.yaml";
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # --- Passwords ---
  sops.secrets."abhay-password" = {
    neededForUsers = true;
  };

  # --- SSH ---
  services.openssh = {
    enable = true;
    ports = [2442];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users."root".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
  ];

  # --- Sudo config (Run commands without root) ---
  security.sudo.extraRules = [
    {
      users = ["abhay"];
      commands = [
        {
          command = "/run/current-system/sw/bin/wakeonlan";
          options = ["NOPASSWD"];
        }
        {
          # Using the absolute path is required for NixOS sudo rules
          command = "/run/current-system/sw/bin/systemctl poweroff";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # --- Firewall ---
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [2442 80 443];
    allowedUDPPorts = [config.services.tailscale.port];
    trustedInterfaces = [config.services.tailscale.interfaceName];
  };

  # --- TailScale ---
  services.tailscale.enable = true;
  networking.nftables.enable = true;
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;

  # --- Logging Constraints ---
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    SystemMaxFileSize=200M
  '';

  # --- NixOS common configurations ---
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      substituters = [
        "https://cache.nixos.org/"
        "https://abhay-infra.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59dX431o0gWypbMrAURkbJ16ZPMQFGpcDShjY="
        "abhay-infra.cachix.org-1:tZoiFgPW9hg6axTG6+oh2pfhic1I09sq7FszGrFc7JY="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
}
