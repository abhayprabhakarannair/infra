{
  preservation.enable = true;

  preservation.preserveAt."/persistent" = {
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
      {
        file = "/etc/ssh/ssh_host_ed25519_key";
        how = "symlink";
        configureParent = true;
        mode = "0600";
      }
      {
        file = "/etc/ssh/ssh_host_ed25519_key.pub";
        how = "symlink";
        configureParent = true;
        mode = "0644";
      }
    ];

    directories = [
      {
        directory = "/etc/NetworkManager/system-connections";
        mode = "0700";
      }
      {
        directory = "/var/lib/tailscale";
        mode = "0700";
      }
      {
        directory = "/var/lib/systemd/backlight";
        mode = "0755";
      }
      {
        directory = "/home/abhay";
        user = "abhay";
        group = "users";
        mode = "0700";
      }
    ];
  };
}
