{
  inputs,
  pkgs,
  ...
}: {
  imports = ["${inputs.self}/home/core.nix"];

  # after_install.sh runs after first boot and needs this tool on server
  # profiles too; desktop-only packages are intentionally not imported here.
  home.packages = [pkgs.ssh-to-age];

  programs.git = {
    enable = true;
    settings.init.defaultBranch = "main";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".ServerAliveInterval = 60;
  };
}
