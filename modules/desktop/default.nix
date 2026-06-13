{pkgs, inputs, ...}: {

 imports =  [ "${inputs.self}/modules/neovim" "${inputs.self}/modules/kitty" ];


  # --- Global fonts ---
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-color-emoji
    ];
  };

  # --- Essential System Packages ---
  environment.systemPackages = with pkgs; [
    jq
    tree
    sops
    age
    ssh-to-age
    mkpasswd
    ripgrep
    git
  ];


  # --- FISH across all desktops ---
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;

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
}
