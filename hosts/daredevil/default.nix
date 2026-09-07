{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./preservation.nix
  ];

  home-manager.users.abhay = {
    home.username = "abhay";
    home.homeDirectory = "/home/abhay";
    home.stateVersion = "26.05";

    programs.home-manager.enable = true;
    programs.bash.enable = true;

    xdg.configFile."niri/config.kdl".text = ''
      input {
        keyboard {
          xkb {
            layout "us"
          }
        }
        touchpad {
          tap
          natural-scroll
        }
      }

      layout {
        gaps 8
        center-focused-column "never"
        default-column-width { proportion 0.5; }
      }

      spawn-at-startup "${pkgs.waybar}/bin/waybar"
      spawn-at-startup "${pkgs.mako}/bin/mako"
      spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet" "--indicator"
      spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-c" "#1e1e1e"
      spawn-at-startup "${pkgs.swayidle}/bin/swayidle" "-w" "timeout" "900" "${pkgs.swaylock}/bin/swaylock -f" "before-sleep" "${pkgs.swaylock}/bin/swaylock -f"
      spawn-at-startup "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

      binds {
        Mod+Return { spawn "${pkgs.foot}/bin/foot"; }
        Mod+D { spawn "${pkgs.fuzzel}/bin/fuzzel"; }
        Mod+Q { close-window; }
        Mod+Shift+E { quit; }
        Mod+Alt+L { spawn "${pkgs.swaylock}/bin/swaylock" "-f"; }
        Mod+H { focus-column-left; }
        Mod+J { focus-window-down; }
        Mod+K { focus-window-up; }
        Mod+L { focus-column-right; }
        Mod+Shift+H { move-column-left; }
        Mod+Shift+J { move-window-down; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+L { move-column-right; }
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+Shift+Page_Down { move-column-to-workspace-down; }
        Mod+Shift+Page_Up { move-column-to-workspace-up; }
        Mod+Tab { toggle-overview; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+O { toggle-window-floating; }
        Mod+Shift+O { switch-focus-between-floating-and-tiling; }
        Mod+Escape { toggle-keyboard-shortcuts-inhibit; }
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }
        XF86AudioRaiseVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      }
    '';

    xdg.configFile."waybar/config.jsonc".text = builtins.toJSON {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = ["niri/workspaces"];
      modules-center = ["niri/window"];
      modules-right = ["network" "wireplumber" "battery" "clock" "tray"];
      "niri/workspaces" = {
        format = "{icon}";
        "format-icons" = {
          active = "●";
          default = "○";
        };
      };
      "niri/window" = {
        format = "{}";
        "separate-outputs" = true;
      };
      network = {
        format-wifi = "Wi-Fi {essid}";
        format-ethernet = "Ethernet";
        "format-disconnected" = "Offline";
      };
      wireplumber = {
        format = "Audio {volume}%";
        "format-muted" = "Audio muted";
      };
      battery = {
        format = "Battery {capacity}%";
        "format-charging" = "Charging {capacity}%";
      };
      clock = {
        format = "{:%Y-%m-%d %H:%M}";
      };
    };

    xdg.configFile."waybar/style.css".text = ''
      * {
        border: none;
        border-radius: 0;
        font-family: sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(30, 30, 30, 0.96);
        color: #eeeeee;
      }

      #workspaces button,
      #window,
      #network,
      #wireplumber,
      #battery,
      #clock,
      #tray {
        padding: 0 8px;
      }

      #workspaces button.focused {
        color: #89b4fa;
      }
    '';
  };

  networking.hostName = "daredevil";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  programs.niri.enable = true;

  hardware.graphics.enable = true;

  security.polkit.enable = true;
  security.pam.services.swaylock = {};
  security.pam.services.greetd.enableGnomeKeyring = true;

  security.rtkit.enable = true;

  services.gnome.gnome-keyring.enable = true;

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --cmd ${pkgs.niri}/bin/niri-session";
        user = "greeter";
      };
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["tpm_tis"];
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["mode=755" "size=25%"];
  };
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persistent".neededForBoot = true;

  systemd.suppressedSystemUnits = ["systemd-machine-id-commit.service"];

  users.users.abhay = {
    isNormalUser = true;
    description = "Abhay Prabhakaran Nair";
    extraGroups = ["wheel" "networkmanager"];
    hashedPasswordFile = config.sops.secrets."abhay-password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+mIhyn0WleD0sBHsS6IARv9y0KAXpi+0rTc0K0vZTD"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPgXwAtS1XN9OnFTlFoPToo2SDaNkooel5kReyOUzYT"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  sops.defaultSopsFile = ../../secrets/system-secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/persistent/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets."abhay-password".neededForUsers = true;

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    btrfs-progs
    cryptsetup
    git
    htop
    fuzzel
    foot
    grim
    mako
    networkmanagerapplet
    pciutils
    polkit_gnome
    slurp
    swaybg
    swayidle
    swaylock
    thunar
    usbutils
    vim
    waybar
    wl-clipboard
    xwayland-satellite
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  system.stateVersion = "26.05";
}
