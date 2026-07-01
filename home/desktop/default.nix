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
      nrs = "sudo nixos-rebuild switch --flake ~/Projects/infra#$(cat /etc/hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/Projects/infra#$(cat /etc/hostname)";
      ve = "nvim .";
      ainext = "echo \$argv > ~/.ai_next_step.txt";
    };

    interactiveShellInit = ''
     set -g fish_greeting

     # --- Project Personalized AI: Terminal Anchor ---
     if test -f ~/.ai_next_step.txt
         set_color yellow
         echo ""
         echo "========================================"
         echo "🤖 AI COMPANION NEXT STEP:"
         set_color green
         cat ~/.ai_next_step.txt
         set_color yellow
         echo "========================================"
         set_color normal
         echo ""
     end
    '';
  };

  # --- DIR Env ---
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; 
    
    config = {
      global = {
        hide_env_diff = true;
      };
    };
  };
}
