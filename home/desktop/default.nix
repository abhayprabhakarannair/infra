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

      # --- Auto-Symlink AI State ---
      # Check if local symlink is missing, but the file exists in Sync.
      # If so, automatically restore the symlink on this device.
      set sync_target ~/Sync/Shared/Core/ai_next_step.txt
      set local_link ~/.ai_next_step.txt

      if not test -e $local_link
          if test -f $sync_target
              ln -s $sync_target $local_link
          end
      end

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
