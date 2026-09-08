{
  config,
  pkgs,
  ...
}:
{
  # Password success ends authentication; empty/incorrect input falls back
  # to the enrolled fingerprint instead of delaying a correct password.
  security.pam.services.swaylock = {
    fprintAuth = true;
    rules.auth.fprintd.order = config.security.pam.services.swaylock.rules.auth.unix.order + 10;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 85;
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
  # This ThinkPad's digital microphone is software-muted by PipeWire, while
  # audio-micmute follows a different ALSA capture control. Use the same
  # default source as the hardware key and Waybar, including USB headsets.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/brightness"
  '';
  home-manager.users.abhay.systemd.user.services.microphone-led = {
    Unit = {
      Description = "Follow the default PipeWire microphone mute state";
      After = ["wireplumber.service"];
      PartOf = ["graphical-session.target"];
      ConditionPathExists = "/sys/class/leds/platform::micmute";
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "microphone-led" ''
        set -eu
        led=/sys/class/leds/platform::micmute/brightness
        while true; do
          if volume=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null); then
            case "$volume" in
              *MUTED*) desired=1 ;;
              *) desired=0 ;;
            esac
            if [ "$(cat "$led")" != "$desired" ]; then
              printf '%s\n' "$desired" > "$led"
            fi
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
      ''}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };
}
