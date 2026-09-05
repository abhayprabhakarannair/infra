{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.self}/modules/desktop/nixvim.nix"];

  # Desktop persistence follows the XDG boundary instead of enumerating every
  # application. Configuration and user data survive resets; ~/.cache and
  # other transient top-level state remain ephemeral. The few non-XDG user
  # directories below are standard credentials/data locations, not app lists.
  myImpermanence.homeDirectories = [
    "Desktop"
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Projects"
    "Public"
    "Sync"
    "Templates"
    "Videos"
    ".config"
    ".local/share"
    ".local/state"
    ".ssh"
    ".gnupg"
    ".pki"
    ".var/app"
    ".codex"
  ];
  myImpermanence.homeFiles = [".bash_history"];

  # --- Global fonts ---
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-color-emoji
      noto-fonts
      smc-manjari
      smc-chilanka
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = ["Noto Serif Malayalam" "Noto Serif"];
        sansSerif = ["Manjari" "Noto Sans Malayalam" "Noto Sans"];
        monospace = ["JetBrainsMono Nerd Font" "Manjari" "Noto Sans Malayalam"];
      };
    };
  };

  # --- Essential System Packages ---
  environment.systemPackages = with pkgs; [
    bubblewrap
    jq
    tree
    sops
    age
    ssh-to-age
    mkpasswd
    ripgrep
    git
    gcc
    gnumake
    rustup
    unzip
    curl
    alejandra
    stylua
    zlib
    herdr

    google-chrome
  ];

  xdg.mime.defaultApplications = {
    "text/html" = "vivaldi-stable.desktop";
    "x-scheme-handler/http" = "vivaldi-stable.desktop";
    "x-scheme-handler/https" = "vivaldi-stable.desktop";
  };

  # Playwright channel:"chrome" looks for /opt/google/chrome/chrome
  systemd.tmpfiles.rules = [
    "L+ /opt/google/chrome/chrome - - - - ${pkgs.google-chrome}/bin/google-chrome-stable"
    # Repair the top-level user state roots left by older generations. The
    # one-time migration also normalizes their declared contents recursively.
    "z /home/abhay/.config 0755 abhay users -"
    "z /home/abhay/.local/share 0755 abhay users -"
    "z /home/abhay/.local/state 0755 abhay users -"
    "z /persist/home/abhay/.config 0755 abhay users -"
    "z /persist/home/abhay/.local/share 0755 abhay users -"
    "z /persist/home/abhay/.local/state 0755 abhay users -"
  ];

  environment.sessionVariables = {
    CHROME_BIN = "${pkgs.google-chrome}/bin/google-chrome-stable";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  # --- Bash across all desktops ---
  users.defaultUserShell = pkgs.bashInteractive;

  # --- Add firmware upgrades ---
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;

  # --- Common desktop hardware ---
  hardware.graphics.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  # --- Sound ---
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
      curl
      glibc
      libffi
    ];
  };
}
