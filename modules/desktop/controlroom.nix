{inputs, config, ...}: {
 sops.secrets."ssh-secret-ips" = {
    owner = config.users.users.abhay.name;
    group = config.users.users.abhay.group;
    mode = "0400";
 };

 sops.secrets."ssh-private-keys/github" = {
    owner = config.users.users.abhay.name;
    group = config.users.users.abhay.group;
    mode = "0400";
  };

  sops.secrets."ssh-private-keys/homelab" = {
    owner = config.users.users.abhay.name;
    group = config.users.users.abhay.group;
    mode = "0400";
  };

}
