{
  inputs,
  config,
  ...
}: {
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

  sops.secrets."ssh-private-keys/forge" = {
    owner = config.users.users.abhay.name;
    group = config.users.users.abhay.group;
    mode = "0400";
  };

  # --- sign commits perm ---
  environment.etc."git/allowed_signers".text = ''
    # Personal Devices
    abhayprabhakarannair@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP0W8o0Bw9wa67ymsVVpspRXsFPcAk5yl9wFlZKecXpC

    # Forgejo UI commits
    noreply@git.iamabhay.fyi ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMqx32jYbfgpOJY9k3LP2sCkFGiNm6IJ5uY6kDmRUGAG
  '';
}
