{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myImpermanence;

  commonSystemDirectories = [
    "/var/lib/nixos"
    "/var/lib/tailscale"
    "/etc/NetworkManager/system-connections"
    "/var/lib/bluetooth"
    "/var/log/journal"
  ];

  commonSystemFiles = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
    "/var/lib/systemd/random-seed"
  ];

  snapshotTool = pkgs.writeShellApplication {
    name = "impermanence-snapshot";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      if ! mountpoint --quiet /persist; then
        echo "impermanence-snapshot: /persist is not mounted" >&2
        exit 1
      fi

      stamp=$(date -u +%Y%m%d-%H%M%S)
      destination="/persist/rollback/$stamp"
      mkdir -p "$destination"

      btrfs subvolume snapshot -r / "$destination/root"
      btrfs subvolume snapshot -r /home "$destination/home"

      if btrfs subvolume show /srv >/dev/null 2>&1; then
        btrfs subvolume snapshot -r /srv "$destination/srv"
      fi

      echo "Created read-only rollback snapshots under $destination"
    '';
  };

  prepareReset = pkgs.writeShellScript "impermanence-prepare-reset" ''
    set -eu

    marker=/persist/.impermanence-ready
    rollback=/persist/rollback

    if ! ${pkgs.util-linux}/bin/mountpoint --quiet /persist; then
      echo "impermanence-prepare-reset: /persist is not mounted" >&2
      exit 1
    fi

    has_snapshot=no
    for candidate in "$rollback"/*; do
      if [ -d "$candidate" ]; then
        has_snapshot=yes
        break
      fi
    done

    # The marker gates destructive resets. If an older recovery attempt left
    # the marker behind without a rollback snapshot, create the missing point
    # before allowing the next reset.
    if [ -e "$marker" ] && [ "$has_snapshot" = yes ]; then
      exit 0
    fi

    stamp=$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S)
    destination="$rollback/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$destination"

    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r / "$destination/root"
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /home "$destination/home"

    if ${pkgs.btrfs-progs}/bin/btrfs subvolume show /srv >/dev/null 2>&1; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /srv "$destination/srv"
    fi

    ${pkgs.coreutils}/bin/touch "$marker"
    echo "Created read-only rollback snapshots under $destination"
  '';

  cleanupSystemFiles = pkgs.writeShellScript "impermanence-clean-system-files" ''
    for path in \
      /etc/machine-id \
      /etc/ssh/ssh_host_ed25519_key \
      /etc/ssh/ssh_host_ed25519_key.pub \
      /etc/ssh/ssh_host_rsa_key \
      /etc/ssh/ssh_host_rsa_key.pub \
      /var/lib/systemd/random-seed; do
      if [ -e "$path" ] && ! ${pkgs.util-linux}/bin/findmnt --mountpoint "$path" >/dev/null 2>&1; then
        # A concurrently-started persistence mount can make the file busy
        # after the check. That is harmless: the bind mount already owns it.
        rm -f -- "$path" 2>/dev/null || true
      fi
    done
  '';
in {
  options.myImpermanence = {
    enable = lib.mkEnableOption "explicit persistent state boundaries";

    serviceDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Service state directories retained under /persist.";
    };

    homeDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Sync"
        ".config/syncthing"
        ".local/share/keyrings"
        ".local/state/nix"
        ".ssh"
      ];
      description = "User directories retained by Home Manager impermanence.";
    };

    homeFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "User files retained by Home Manager impermanence.";
    };

    extraSystemDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional system directories retained under /persist.";
    };

    extraSystemFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional system files retained under /persist.";
    };

    reset = {
      enable = lib.mkEnableOption "Btrfs reset of undeclared root and home state";

      device = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Btrfs device containing the root and persistence subvolumes.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.reset.enable || cfg.reset.device != "";
        message = "myImpermanence.reset.device must be set when reset is enabled.";
      }
    ];

    fileSystems."/persist".neededForBoot = true;
    fileSystems."/home".neededForBoot = true;

    system.activationScripts.impermanence-clean-system-files = {
      deps = ["createPersistentStorageDirs"];
      text = "${cleanupSystemFiles}";
    };
    system.activationScripts.persist-files.deps = lib.mkAfter [
      "impermanence-clean-system-files"
    ];

    # Prepare the rollback point during the activation that enables reset.
    # The following reboot is then the first destructive reset.
    system.activationScripts.impermanence-prepare-reset = lib.mkIf cfg.reset.enable {
      deps = ["createPersistentStorageDirs"];
      text = "${prepareReset}";
    };

    # NixOS and sshd-keygen may create these files before impermanence's
    # mount units run. Remove the ephemeral copies first so the persisted
    # files can be bind-mounted in their place.
    systemd.services.impermanence-clean-system-files = {
      description = "Remove ephemeral copies of persisted system files";
      wantedBy = ["local-fs.target"];
      before = [
        "local-fs.target"
        "persist-persist-etc-machine\\x2did.service"
        "persist-persist-etc-ssh-ssh_host_ed25519_key.service"
        "persist-persist-etc-ssh-ssh_host_ed25519_key.pub.service"
        "persist-persist-etc-ssh-ssh_host_rsa_key.service"
        "persist-persist-etc-ssh-ssh_host_rsa_key.pub.service"
        "persist-persist-var-lib-systemd-random\\x2dseed.service"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = cleanupSystemFiles;
      };
    };

    systemd.services.abhay-home-permissions = {
      description = "Prepare abhay's home directory for Home Manager";
      wantedBy = ["home-manager-abhay.service"];
      before = ["home-manager-abhay.service"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "abhay-home-permissions" ''
          install -d -o abhay -g users -m 0755 \
            /home/abhay/.config \
            /home/abhay/.local \
            /home/abhay/.local/share \
            /home/abhay/.local/state \
            /home/abhay/.local/state/nix \
            /home/abhay/.local/state/nix/profiles
          chown abhay:users \
            /home/abhay \
            /home/abhay/.config \
            /home/abhay/.local \
            /home/abhay/.local/share \
            /home/abhay/.local/state \
            /home/abhay/.local/state/nix \
            /home/abhay/.local/state/nix/profiles
          chmod 0755 \
            /home/abhay \
            /home/abhay/.config \
            /home/abhay/.local \
            /home/abhay/.local/share \
            /home/abhay/.local/state
        '';
      };
    };

    # The reset service runs before the normal system closure is available.
    # Include the tools it invokes in the initrd explicitly.
    boot.initrd.systemd.storePaths = [pkgs.util-linux pkgs.btrfs-progs];

    # A freshly reset @home is created by root. Home Manager activates as the
    # user and therefore needs its home directory owned by abhay first.
    systemd.tmpfiles.rules = [
      "z /home/abhay 0755 abhay users -"
      "z /home/abhay/.config 0755 abhay users -"
      "z /home/abhay/.local 0755 abhay users -"
      "z /home/abhay/.local/share 0755 abhay users -"
      "z /home/abhay/.local/state 0755 abhay users -"
      "z /home/abhay/.local/state/nix 0755 abhay users -"
      "z /home/abhay/.local/state/nix/profiles 0755 abhay users -"
    ];

    environment.persistence."/persist" = {
      hideMounts = true;
      directories =
        commonSystemDirectories
        ++ cfg.extraSystemDirectories
        ++ cfg.serviceDirectories;
      files = commonSystemFiles ++ cfg.extraSystemFiles;
    };

    home-manager.users.abhay.home.persistence."/persist" = {
      directories = cfg.homeDirectories;
      files = cfg.homeFiles;
    };

    environment.systemPackages = [snapshotTool];

    boot.initrd.systemd.services.impermanence-reset = lib.mkIf cfg.reset.enable {
      description = "Reset undeclared impermanent root and home state";
      wantedBy = ["initrd.target"];
      before = [
        "initrd-fs.target"
        "initrd-root-fs.target"
        "sysroot.mount"
        "sysroot-home.mount"
        "sysroot-nix.mount"
        "sysroot-persist.mount"
      ];
      after = ["initrd-root-device.target"];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "infinity";
      };
      script = ''
        set -eu

        impermanence_btrfs_device=${lib.escapeShellArg cfg.reset.device}
        impermanence_btrfs_root=/run/impermanence-btrfs-root
        mkdir -p "$impermanence_btrfs_root"
        ${pkgs.util-linuxMinimal}/bin/mount -t btrfs -o subvolid=5 "$impermanence_btrfs_device" "$impermanence_btrfs_root"
        impermanence_log="$impermanence_btrfs_root/@persist/.impermanence-reset.log"
        exec 9>"$impermanence_log"
        log() { echo "impermanence-reset: $*" >&9; }
        log "mounted top-level Btrfs"

        # The marker is created only after the live migration has copied the
        # allowlisted state into @persist and the rollback snapshot exists.
        if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-ready" ]; then
          log "migration marker absent; keeping existing subvolumes"
          ${pkgs.util-linuxMinimal}/bin/umount "$impermanence_btrfs_root"
          exit 0
        fi

        for impermanence_subvolume in @ @home; do
          log "deleting $impermanence_subvolume"
          if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$impermanence_btrfs_root/$impermanence_subvolume"
          fi
          ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$impermanence_btrfs_root/$impermanence_subvolume"
          log "created $impermanence_subvolume"
        done

        sync
        log "subvolume reset complete"
        ${pkgs.util-linuxMinimal}/bin/umount "$impermanence_btrfs_root"
        log "unmounted top-level Btrfs"
      '';
    };
  };
}
