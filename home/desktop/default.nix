{
  inputs,
  config,
  ...
}: {
  imports = ["${inputs.self}/home/core.nix"];

  # --- FISH Configuration ---
  programs.fish = {
    enable = true;

    functions = {
     fish_prompt = ''
      set_color cyan
      echo -n (prompt_pwd)
      set_color normal
      echo -n " => "
     '';
    };

    shellAliases = {
      ll = "ls -larth";
      nrs = "sudo nixos-rebuild switch --flake ~/Projects/infra#\$(cat /etc/hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/Projects/infra#\$(cat /etc/hostname)";
      ve = "nvim .";
    };

    interactiveShellInit = ''
     set -g fish_greeting
    '';
  };


}
