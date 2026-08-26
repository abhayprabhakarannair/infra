{inputs, ...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [
      "/run/secrets/ssh-secret-ips"
    ];

    settings = {
      "*" = {
        ServerAliveInterval = 60;
        StrictHostKeyChecking = "accept-new";
      };

      "homelab-one" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "old-devil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "lucifer" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "daredevil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "devil" = {
        User = "abhay";
        Port = 2442;
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = "yes";
      };

      "homelab-storage-one" = {
        IdentityFile = "~/.ssh/id_ed25519";
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
