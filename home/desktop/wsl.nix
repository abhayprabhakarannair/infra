{inputs, config, ...}: {

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Abhay Nair";
        email = "anair@korewireless.com";
	signingkey = "${config.home.homeDirectory}/.ssh/id_ed25519_github.pub";
      };
      init = {
        defaultBranch = "main";
      };
      core = {
        excludesFileShow = "more";
      };
      gpg = {
        format = "ssh";
	ssh = {
          allowedSignersFile = "${config.home.homeDirectory}/.ssh/allowed_signers";
        };
      };
      commit = {
        gpgsign = true;
      };
    };
  };

  # --- SSH ---
  programs.ssh = {
   enable = true;
   enableDefaultConfig = false;

   settings = {
    "*" = {
      ServerAliveInterval = 60;
    };

    "gitlab.com" = {
      User = "git";
      identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
      IdentitiesOnly = "yes";
      AddKeysToAgent = "yes";
    };

   };
  };


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
      hrs = "home-manager switch --flake ~/Projects/infra#$(whoami)@$(cat /etc/hostname)";
      ve = "nvim .";
    };

    interactiveShellInit = ''
      set -g fish_greeting
      
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
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

  home.username = "abhay";
  home.homeDirectory = "/home/abhay";


  home.stateVersion = "26.05";
}
