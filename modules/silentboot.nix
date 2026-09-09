{...}: {
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "rd.systemd.show_status=false"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };
}
