{
  config,
  kanagawa,
  pkgs,
  ...
}:
{
  home-manager.users.abhay = {
    home.username = "abhay";
    home.homeDirectory = "/home/abhay";
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
    programs.bash.enable = true;
    programs.bash.shellAliases = {
      ll = "ls -larth";
      nrb = "sudo nixos-rebuild build --flake ~/Projects/infra#${config.networking.hostName}";
      nrs = "sudo nixos-rebuild switch --flake ~/Projects/infra#${config.networking.hostName}";
      ve = "nvim .";
    };
    programs.bash.initExtra = ''
      PS1='\[\e[38;2;126;156;216m\]\u@\h \[\e[38;2;114;113;105m\]\w \[\e[38;2;152;187;108m\]\$\[\e[0m\] '
    '';

    programs.foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font Mono:size=10";
          pad = "12x10";
          dpi-aware = "yes";
          term = "xterm-256color";
        };
        scrollback = {
          lines = 10000;
          multiplier = 3;
        };
        cursor = {
          style = "beam";
          blink = "yes";
        };
        mouse.hide-when-typing = "yes";
        url = {
          launch = ''
            ${pkgs.xdg-utils}/bin/xdg-open ''${url}
          '';
        };
        "colors-dark" = {
          alpha = "0.96";
          background = kanagawa.sumiInk1;
          foreground = kanagawa.fujiWhite;
          regular0 = kanagawa.sumiInk1;
          regular1 = kanagawa.autumnRed;
          regular2 = kanagawa.springGreen;
          regular3 = kanagawa.boatYellow;
          regular4 = kanagawa.crystalBlue;
          regular5 = kanagawa.sakuraPink;
          regular6 = kanagawa.springBlue;
          regular7 = kanagawa.fujiWhite;
          bright0 = kanagawa.sumiInk3;
          bright1 = kanagawa.autumnRed;
          bright2 = kanagawa.springGreen;
          bright3 = kanagawa.boatYellow;
          bright4 = kanagawa.crystalBlue;
          bright5 = kanagawa.sakuraPink;
          bright6 = kanagawa.springBlue;
          bright7 = "ffffff";
          selection-foreground = kanagawa.sumiInk1;
          selection-background = kanagawa.crystalBlue;
        };
        key-bindings = {
          scrollback-up-page = "Page_Up";
          scrollback-down-page = "Page_Down";
          clipboard-copy = "Control+Shift+c";
          clipboard-paste = "Control+Shift+v";
          show-urls-launch = "Control+Shift+o";
          show-urls-copy = "Control+Shift+y";
        };
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
    };

    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "abhayprabhakarannair";
          email = "abhayprabhakarannair@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "/run/secrets/ssh-secret-ips" ];
      settings = {
        "*" = {
          ServerAliveInterval = 60;
        };
        homelab-one = {
          User = "abhay";
          Port = 2442;
          IdentityFile = "/run/secrets/ssh-private-keys/homelab";
          IdentitiesOnly = "yes";
        };
        old-devil = {
          User = "abhay";
          Port = 2442;
          IdentityFile = "/run/secrets/ssh-private-keys/homelab";
          IdentitiesOnly = "yes";
        };
        daredevil = {
          User = "abhay";
          Port = 2442;
          IdentityFile = "/run/secrets/ssh-private-keys/homelab";
          IdentitiesOnly = "yes";
        };
        devil = {
          User = "abhay";
          Port = 2442;
          IdentityFile = "/run/secrets/ssh-private-keys/homelab";
          IdentitiesOnly = "yes";
        };
        homelab-storage-one = {
          IdentityFile = "/run/secrets/ssh-private-keys/homelab";
          IdentitiesOnly = "yes";
        };
        "github.com" = {
          User = "abhay";
          IdentityFile = "/run/secrets/ssh-private-keys/github";
          IdentitiesOnly = "yes";
        };
      };
    };

  };
}
