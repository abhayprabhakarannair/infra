{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "abhayprabhakarannair";
        email = "abhayprabhakarannair@gmail.com";
      };
      init = {
        defaultBranch = "main";
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

  home.stateVersion = "26.05";
}
