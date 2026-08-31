{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "abhayprabhakarannair";
        email = "abhayprabhakarannair@gmail.com";
        signingkey = "/run/secrets/ssh-private-keys/forge";
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

      "git.iamabhay.fyi" = {
        User = "abhay";
        Port = 2222;
        IdentityFile = "/run/secrets/ssh-private-keys/forge";
        IdentitiesOnly = "yes";
      };
    };
  };

  home.stateVersion = "26.05";
}
