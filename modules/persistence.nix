{
  config,
  inputs,
  ...
}:
{
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
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=15
    Defaults timestamp_type=global
    Defaults lecture=once
    Defaults pwfeedback
    Defaults insults
  '';

  sops.defaultSopsFile = "${inputs.self}/secrets/system-secrets.yaml";
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets."abhay-password".neededForUsers = true;
  sops.secrets."ssh-secret-ips" = {
    owner = "abhay";
    group = "users";
    mode = "0400";
  };
  sops.secrets."ssh-private-keys/github" = {
    owner = "abhay";
    group = "users";
    mode = "0400";
  };
  sops.secrets."ssh-private-keys/homelab" = {
    owner = "abhay";
    group = "users";
    mode = "0400";
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [2442];
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = true;
    };
  };
}
