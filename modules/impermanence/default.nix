{
  config,
  lib,
  pkgs,
  utils,
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
    migration_marker=/persist/.impermanence-state-seeded-v3

    seed_file() {
      source="$1"
      target="$2"
      if [ -e "$source" ] && [ ! -e "$target" ] && [ ! -L "$target" ]; then
        ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
        ${pkgs.coreutils}/bin/cp -a -- "$source" "$target"
      fi
    }

    seed_directory() {
      source="$1"
      target="$2"
      [ -d "$source" ] || return 0
      ${pkgs.coreutils}/bin/mkdir -p "$target"

      # Copy only entries missing from persistence. This makes the migration
      # additive and never overwrites state already established there.
      for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        name="''${entry##*/}"
        if [ ! -e "$target/$name" ] && [ ! -L "$target/$name" ]; then
          ${pkgs.coreutils}/bin/cp -a -- "$entry" "$target/$name"
        fi
      done
    }

    seed_declared_state() {
      service_snapshot_root="$destination/root"
      if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$destination/srv" >/dev/null 2>&1; then
        # Newer layouts may have a dedicated @srv snapshot. Prefer it when
        # present; otherwise /srv lives below the root snapshot.
        service_snapshot_root="$destination/srv"
      fi

      ${seedSystemDirectories}
      ${seedServiceDirectories}
      ${seedHomeDirectories}
      ${seedSystemFiles}
      ${seedHomeFiles}

      # Existing persistence directories may have been created by an older
      # cutover with the wrong owner. Normalize only the declared user state,
      # once, so applications can write normally without app-specific fixes.
      ${seedHomeOwnership}
    }

    if ! ${pkgs.util-linux}/bin/mountpoint --quiet /persist; then
      echo "impermanence-prepare-reset: /persist is not mounted" >&2
      exit 1
    fi

    has_snapshot=no
    latest_snapshot=
    for candidate in "$rollback"/*; do
      if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$candidate/root" >/dev/null 2>&1 && \
        ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$candidate/home" >/dev/null 2>&1; then
        has_snapshot=yes
        latest_snapshot="$candidate"
      fi
    done

    # The marker gates destructive resets. If an older recovery attempt left
    # the marker behind without a rollback snapshot, create the missing point
    # before allowing the next reset.
    if [ -e "$marker" ] && [ "$has_snapshot" = yes ]; then
      if [ ! -e "$migration_marker" ]; then
        destination="$latest_snapshot"
        seed_declared_state
        ${pkgs.coreutils}/bin/touch "$migration_marker"
      fi
      exit 0
    fi

    stamp=$(${pkgs.coreutils}/bin/date -u +%Y%m%d-%H%M%S)
    destination="$rollback/$stamp"
    ${pkgs.coreutils}/bin/mkdir -p "$destination"

    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r / "$destination/root"
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /home "$destination/home"

    if [ -d /srv ] && ${pkgs.btrfs-progs}/bin/btrfs subvolume show /srv >/dev/null 2>&1; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r /srv "$destination/srv"
    fi

    seed_declared_state
    ${pkgs.coreutils}/bin/touch "$migration_marker"
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

  persistentSystemDirectories =
    commonSystemDirectories
    ++ cfg.extraSystemDirectories;

  seedSystemDirectories =
    lib.concatMapStringsSep "\n" (path: ''
      seed_directory "$destination/root${path}" "/persist${path}"
    '')
    persistentSystemDirectories;

  seedServiceDirectories = lib.concatMapStringsSep "\n" (path:
    if lib.hasPrefix "/srv/" path
    then ''
      seed_directory "$service_snapshot_root/srv/${lib.removePrefix "/srv/" path}" "/persist${path}"
    ''
    else ''
      seed_directory "$destination/root${path}" "/persist${path}"
    '')
  cfg.serviceDirectories;

  seedHomeDirectories =
    lib.concatMapStringsSep "\n" (path: ''
      seed_directory "$destination/home/abhay/${path}" "/persist/home/abhay/${path}"
    '')
    cfg.homeDirectories;

  seedSystemFiles = lib.concatMapStringsSep "\n" (path: ''
    seed_file "$destination/root${path}" "/persist${path}"
  '') (commonSystemFiles ++ cfg.extraSystemFiles);

  seedHomeFiles =
    lib.concatMapStringsSep "\n" (path: ''
      seed_file "$destination/home/abhay/${path}" "/persist/home/abhay/${path}"
    '')
    cfg.homeFiles;

  seedHomeOwnership =
    lib.concatMapStringsSep "\n" (path: ''
      if [ -e "/persist/home/abhay/${path}" ]; then
        ${pkgs.coreutils}/bin/chown -R abhay:users -- "/persist/home/abhay/${path}"
      fi
    '')
    cfg.homeDirectories;

  persistentDirectoryPaths =
    (commonSystemDirectories
      ++ cfg.extraSystemDirectories
      ++ cfg.serviceDirectories)
    ++ map (path: "/home/abhay/${path}") cfg.homeDirectories;

  persistentFilePaths =
    (commonSystemFiles ++ cfg.extraSystemFiles)
    ++ map (path: "/home/abhay/${path}") cfg.homeFiles;

  persistenceDirectoryMounts =
    map (path: {
      before = ["local-fs.target"];
      where = path;
      wantedBy = ["local-fs.target"];
      what = "/persist${path}";
      type = "none";
      options = "bind,x-gvfs-hide";
      unitConfig = {
        After = ["persist.mount"];
        DefaultDependencies = false;
        Requires = ["persist.mount"];
      };
    })
    persistentDirectoryPaths;

  persistenceFileServices = lib.genAttrs (map (path: "persist-${utils.escapeSystemdPath "/persist${path}"}") persistentFilePaths) (_: {
    unitConfig = {
      After = ["persist.mount"];
      Requires = ["persist.mount"];
    };
  });

  preflightPersistentDirectories =
    lib.concatMapStringsSep "\n" (path: ''
      if [ ! -d "$impermanence_btrfs_root/@persist${path}" ]; then
        log "required persistent directory is missing: /persist${path}"
        exit 1
      fi
    '')
    persistentDirectoryPaths;
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
        ".config/sops/age"
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
    systemd.services = lib.mkMerge [
      {
        "impermanence-clean-system-files" = {
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

        "abhay-home-permissions" = {
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
      }
      persistenceFileServices
    ];

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

    # impermanence generates these units with DefaultDependencies=false and
    # Before=local-fs.target. Make the dependency on the filesystem that
    # backs /persist explicit, otherwise a bind mount can attach to the
    # ephemeral mountpoint before persist.mount has completed.
    systemd.mounts = lib.mkBefore persistenceDirectoryMounts;

    home-manager.users.abhay.home.persistence."/persist" = {
      hideMounts = true;
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
        impermanence_subvolumes="@ @home"
        impermanence_reset_complete=no
        impermanence_mounted=no
        mkdir -p "$impermanence_btrfs_root"

        cleanup() {
          impermanence_status=$?

          if [ "$impermanence_reset_complete" != yes ]; then
            # If a transactional rename was interrupted, discard only the
            # newly-created empty subvolumes and restore the old names.
            for impermanence_subvolume in $impermanence_subvolumes; do
              if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
                if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
                  ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
                fi
                ${pkgs.btrfs-progs}/bin/btrfs subvolume rename \
                  "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" \
                  "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
              elif ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1; then
                ${pkgs.btrfs-progs}/bin/btrfs subvolume delete \
                  "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1 || true
              fi
            done
          fi

          if ${pkgs.util-linuxMinimal}/bin/mountpoint --quiet "$impermanence_btrfs_root"; then
            ${pkgs.util-linuxMinimal}/bin/umount "$impermanence_btrfs_root" \
              || ${pkgs.util-linuxMinimal}/bin/umount --lazy "$impermanence_btrfs_root" \
              || true
          fi

          trap - EXIT
          exit "$impermanence_status"
        }
        trap cleanup EXIT

        ${pkgs.util-linuxMinimal}/bin/mount -t btrfs -o subvolid=5 "$impermanence_btrfs_device" "$impermanence_btrfs_root"
        impermanence_mounted=yes

        if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/@persist" >/dev/null 2>&1; then
          echo "impermanence-reset: @persist is not a Btrfs subvolume" >&2
          exit 1
        fi

        impermanence_log="$impermanence_btrfs_root/@persist/.impermanence-reset.log"
        exec 9>>"$impermanence_log"
        log() { echo "impermanence-reset: $*" >&9; }
        log "mounted top-level Btrfs"

        # Recover names left by an interrupted transactional switch before
        # evaluating the marker. The old subvolume is always preferred.
        for impermanence_subvolume in @ @home @srv; do
          if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
            if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
            fi
            ${pkgs.btrfs-progs}/bin/btrfs subvolume rename \
              "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" \
              "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1 || true
            log "recovered interrupted reset for $impermanence_subvolume"
          fi
        done

        if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/@srv" >/dev/null 2>&1; then
          impermanence_subvolumes="$impermanence_subvolumes @srv"
        fi

        # The marker is created only after the live migration has copied the
        # allowlisted state into @persist and the rollback snapshot exists.
        if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-ready" ]; then
          log "migration marker absent; keeping existing subvolumes"
          exit 0
        fi

        if [ ! -e "$impermanence_btrfs_root/@persist/.impermanence-state-seeded-v3" ]; then
          log "state migration marker v3 absent; refusing destructive reset"
          exit 1
        fi

        impermanence_latest_snapshot=
        for impermanence_candidate in "$impermanence_btrfs_root/@persist/rollback"/*; do
          if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_candidate/root" >/dev/null 2>&1 && \
            ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_candidate/home" >/dev/null 2>&1; then
            impermanence_latest_snapshot="$impermanence_candidate"
          fi
        done
        if [ -z "$impermanence_latest_snapshot" ]; then
          log "no complete rollback snapshot found; refusing destructive reset"
          exit 1
        fi

        ${preflightPersistentDirectories}

        for impermanence_subvolume in $impermanence_subvolumes; do
          if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume" >/dev/null 2>&1; then
            log "required subvolume is missing: $impermanence_subvolume"
            exit 1
          fi
          if ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" >/dev/null 2>&1 || \
            ${pkgs.btrfs-progs}/bin/btrfs subvolume show "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old" >/dev/null 2>&1; then
            log "transactional reset names already exist for $impermanence_subvolume"
            exit 1
          fi
        done

        # Prepare every replacement before renaming any live subvolume. The
        # old subvolumes remain recoverable until both root and home switch.
        for impermanence_subvolume in $impermanence_subvolumes; do
          ${pkgs.btrfs-progs}/bin/btrfs subvolume create \
            "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new"
          log "prepared $impermanence_subvolume"
        done

        for impermanence_subvolume in $impermanence_subvolumes; do
          ${pkgs.btrfs-progs}/bin/btrfs subvolume rename \
            "$impermanence_btrfs_root/$impermanence_subvolume" \
            "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old"
          ${pkgs.btrfs-progs}/bin/btrfs subvolume rename \
            "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-new" \
            "$impermanence_btrfs_root/$impermanence_subvolume"
          log "switched $impermanence_subvolume"
        done

        # Only remove the old state after every replacement has its final
        # name. If deletion fails, the EXIT trap restores the old names.
        for impermanence_subvolume in $impermanence_subvolumes; do
          ${pkgs.btrfs-progs}/bin/btrfs subvolume delete \
            "$impermanence_btrfs_root/$impermanence_subvolume.impermanence-old"
        done

        sync
        impermanence_reset_complete=yes
        log "subvolume reset complete"
      '';
    };
  };
}
