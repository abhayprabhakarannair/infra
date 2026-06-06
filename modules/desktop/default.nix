{pkgs, inputs, ...}: {

 imports =  [ "${inputs.self}/modules/neovim" ];


  # --- Global fonts ---
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-color-emoji
    ];
  };

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
