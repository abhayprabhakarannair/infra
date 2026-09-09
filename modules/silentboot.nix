{...}: {
  boot.kernelParams = [
    "quiet"
    "splash"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };
}
