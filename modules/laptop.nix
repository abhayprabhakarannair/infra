{
  pkgs,
  ...
}:
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 90;
      RESTORE_THRESHOLDS_ON_BAT = 1;
    };
  };

  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = ["tpm_tis"];
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = ["tpm2-device=auto"];
  boot.kernelParams = [
    "amd_pstate=active"
    "quiet"
    "splash"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelModules = ["snd_ctl_led"];
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };
}
