{config, ...}: {
  users.users.abhay = {
    isNormalUser = true;
    description = "Abhay Prabhakaran Nair";
    extraGroups = ["wheel" "networkmanager" "podman" "video" "libvirtd" "dialout"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
    ];
    hashedPasswordFile = config.sops.secrets."abhay-password".path;
  };
}
