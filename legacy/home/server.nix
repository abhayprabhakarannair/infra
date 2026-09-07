{
  inputs,
  pkgs,
  ...
}: {
  imports = ["${inputs.self}/home/core.nix"];

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
