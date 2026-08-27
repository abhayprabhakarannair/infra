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

  # Reuse the hermes/lucifer SSH key for git commit signing as lucifer
  # (fp SHA256:cmCE1iUc... — same key the lucifer gateway uses).
  sops.secrets."ssh-private-keys/hermes" = {
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

    # Lucifer (hermes gateway signing identity)
    secret@iamabhay.fyi ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPgXwAtS1XN9OnFTlFoPToo2SDaNkooel5kReyOUzYT
  '';
}
