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

  persistentSystemDirectories = commonSystemDirectories ++ cfg.extraSystemDirectories;
  persistentDirectoryPaths =
    (persistentSystemDirectories ++ cfg.serviceDirectories)
    ++ map (path: "/home/abhay/${path}") cfg.homeDirectories;
  persistentFilePaths =
    (commonSystemFiles ++ cfg.extraSystemFiles)
    ++ map (path: "/home/abhay/${path}") cfg.homeFiles;

  seedSystemDirectories =
    lib.concatMapStringsSep "\n" (path: ''
      seed_directory "$destination/root${path}" "/persist${path}"
    '')
    persistentSystemDirectories;

  seedServiceDirectories =
    lib.concatMapStringsSep "\n" (path: ''
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
        chown -R abhay:users -- "/persist/home/abhay/${path}"
      fi
    '')
    cfg.homeDirectories;

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

  persistenceFileServices =
    lib.genAttrs
    (map (path: "persist-${utils.escapeSystemdPath "/persist${path}"}") persistentFilePaths)
    (_: {
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

  snapshotTool = pkgs.writeShellApplication {
    name = "impermanence-snapshot";
    runtimeInputs = [pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux];
    text = builtins.readFile ./snapshot.sh;
  };

  prepareReset = pkgs.replaceVars ./prepare-reset.sh {
    btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
    cp = "${pkgs.coreutils}/bin/cp";
    date = "${pkgs.coreutils}/bin/date";
    dirname = "${pkgs.coreutils}/bin/dirname";
    mkdir = "${pkgs.coreutils}/bin/mkdir";
    mountpoint = "${pkgs.util-linux}/bin/mountpoint";
    touch = "${pkgs.coreutils}/bin/touch";
    seedSystemDirectories = seedSystemDirectories;
    seedServiceDirectories = seedServiceDirectories;
    seedHomeDirectories = seedHomeDirectories;
    seedSystemFiles = seedSystemFiles;
    seedHomeFiles = seedHomeFiles;
    seedHomeOwnership = seedHomeOwnership;
  };

  cleanupSystemFiles = pkgs.replaceVarsWith {
    src = ./cleanup-system-files.sh;
    replacements = {
      findmnt = "${pkgs.util-linux}/bin/findmnt";
      rm = "${pkgs.coreutils}/bin/rm";
    };
    isExecutable = true;
  };

  resetInitrd = pkgs.replaceVars ./reset-initrd.sh {
    btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
    device = lib.escapeShellArg cfg.reset.device;
    mount = "${pkgs.util-linuxMinimal}/bin/mount";
    mountpoint = "${pkgs.util-linuxMinimal}/bin/mountpoint";
    preflightPersistentDirectories = preflightPersistentDirectories;
    umount = "${pkgs.util-linuxMinimal}/bin/umount";
  };
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
      text = builtins.readFile cleanupSystemFiles;
    };
    system.activationScripts.persist-files.deps = lib.mkAfter [
      "impermanence-clean-system-files"
    ];

    system.activationScripts.impermanence-prepare-reset = lib.mkIf cfg.reset.enable {
      deps = ["createPersistentStorageDirs"];
      text = builtins.readFile prepareReset;
    };

    systemd.services = lib.mkMerge [
      {
        impermanence-clean-system-files = {
          description = "Remove ephemeral copies of persisted system files";
          wantedBy = ["local-fs.target"];
          before = [
            "local-fs.target"
            "persist-persist-etc-machine\x2did.service"
            "persist-persist-etc-ssh-ssh_host_ed25519_key.service"
            "persist-persist-etc-ssh-ssh_host_ed25519_key.pub.service"
            "persist-persist-etc-ssh-ssh_host_rsa_key.service"
            "persist-persist-etc-ssh-ssh_host_rsa_key.pub.service"
            "persist-persist-var-lib-systemd-random\x2dseed.service"
          ];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = cleanupSystemFiles;
          };
        };

        abhay-home-permissions = {
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

    boot.initrd.systemd.storePaths = [pkgs.util-linux pkgs.btrfs-progs];

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
      directories = persistentSystemDirectories ++ cfg.serviceDirectories;
      files = commonSystemFiles ++ cfg.extraSystemFiles;
    };

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
      script = builtins.readFile resetInitrd;
    };
  };
}
