{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "abhayprabhakarannair";
        email = "abhayprabhakarannair@gmail.com";
        signingkey = "/run/secrets/ssh-private-keys/github";
      };
      init = {
        defaultBranch = "main";
      };
      gpg = {
        format = "ssh";
        ssh = {
          allowedSignersFile = "/etc/git/allowed_signers";
        };
      };
      commit = {
        gpgsign = true;
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [
      "/run/secrets/ssh-secret-ips"
    ];

    settings = {
      "*" = {
        ServerAliveInterval = 60;
      };

      "homelab-one" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "/run/secrets/ssh-private-keys/homelab";
        IdentitiesOnly = "yes";
      };

      "old-devil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "/run/secrets/ssh-private-keys/homelab";
        IdentitiesOnly = "yes";
      };

      "daredevil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "/run/secrets/ssh-private-keys/homelab";
        IdentitiesOnly = "yes";
      };

      "devil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "/run/secrets/ssh-private-keys/homelab";
        IdentitiesOnly = "yes";
      };

      "homelab-storage-one" = {
        IdentityFile = "/run/secrets/ssh-private-keys/homelab";
        IdentitiesOnly = "yes";
      };

      "github.com" = {
        User = "abhay";
        IdentityFile = "/run/secrets/ssh-private-keys/github";
        IdentitiesOnly = "yes";
      };
    };
  };

  # Keep SSH usable after an impermanence reset without persisting the
  # mutable ~/.ssh directory. Private keys are still supplied by SOPS.
  home.file.".ssh/known_hosts".text = ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    [46.224.15.246]:2442 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINNW154/ZQy08UYPqAB97Pd7fG9lIQCt580PJactfE8v
    [100.117.81.2]:2442 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdlCl+dt+ogsfOt8eqBrQpRwTRNnBEu9RDsKoOsQn0p
    [100.121.11.74]:2442 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnEVwv2EaTihLV97pyVShtTrxNbZwfS2WvYiZBxq3Rq
    [100.77.45.84]:2442 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOQzVY0ekxny7xiqzSWKb/87LEnzUEJ+dNjVDY4XXQvz
    [185.255.94.169]:2442 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG5Zgt6pNt+vsGfeVwFd08NwYXHgPDfu7Y5ZMrsSJoYy
    [git.iamabhay.fyi]:2222 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpKJxGEWH6cEBWH7XUF5FN1ZdxrbC0ZQbjAGcroF3Gy
  '';

  home.stateVersion = "26.05";
}
