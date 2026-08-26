{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  # Individual secret definitions from secrets/service-secrets.yaml
  sops.secrets."hermes/gemini-api-key" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/discord-bot-token" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/discord-allowed-users" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/tavily-api-key" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/dashboard-username" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/dashboard-password" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/dashboard-secret" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."ssh-private-keys/homelab" = {
    sopsFile = "${inputs.self}/secrets/system-secrets.yaml";
    owner = "root";
    group = "hermes";
    mode = "0440";
  };

  sops.secrets."ssh-private-keys/hermes" = {
    sopsFile = "${inputs.self}/secrets/system-secrets.yaml";
    path = "/srv/hermes/.ssh/id_ed25519";
    owner = "hermes";
    group = "hermes";
    mode = "0400";
  };

  # Declarative symlinks and directory structure for Docker socket & Syncthing live vault
  systemd.tmpfiles.rules = [
    "d /srv/hermes 0755 hermes hermes -"
    "d /srv/hermes/.hermes 0700 hermes hermes -"
    "d /srv/hermes/.hermes/cron 0700 hermes hermes -"
    "d /srv/hermes/Sync/Lucifer 0755 hermes hermes -"
    "d /srv/hermes/.ssh 0700 hermes hermes -"
    "L+ /run/docker.sock - - - - /run/podman/podman.sock"
    "L+ /srv/hermes/.hermes/SOUL.md - hermes hermes - /srv/hermes/Sync/Lucifer/SOUL.md"
    "L+ /srv/hermes/SOUL.md - hermes hermes - /srv/hermes/Sync/Lucifer/SOUL.md"
    "L+ /srv/hermes/.hermes/user_feeds.json - hermes hermes - /srv/hermes/Sync/Lucifer/user_feeds.json"
    "L+ /srv/hermes/.hermes/cron/jobs.json - hermes hermes - /srv/hermes/Sync/Lucifer/cron_jobs.json"
    "L+ /srv/hermes/.hermes/AGENTS.md - hermes hermes - /srv/hermes/Sync/Lucifer/AGENTS.md"
  ];

  # Construct the runtime environment file from sops placeholders
  sops.templates."hermes.env" = {
    content = ''
      GEMINI_API_KEY=${config.sops.placeholder."hermes/gemini-api-key"}
      DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes/discord-bot-token"}
      DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes/discord-allowed-users"}
      DISCORD_HOME_CHANNEL=1542031236082565140
      DISCORD_HOME_CHANNEL_NAME="#home"
      DISCORD_REQUIRE_MENTION=false
      DISCORD_THREAD_REQUIRE_MENTION=false
      DISCORD_AUTO_THREAD=false
      DOCKER_HOST=unix:///run/podman/podman.sock
      TAVILY_API_KEY=${config.sops.placeholder."hermes/tavily-api-key"}
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${config.sops.placeholder."hermes/dashboard-username"}
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes/dashboard-password"}
      HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes/dashboard-secret"}
    '';
    restartUnits = ["hermes-agent.service" "hermes-backend.service"];
  };

  services.hermes-agent = {
    enable = true;
    extraDependencyGroups = ["messaging"];
    stateDir = "/srv/hermes";
    workingDirectory = "/srv/hermes/workspace";

    backend = {
      mode = "dashboard";
      host = "0.0.0.0";
      port = 9000;
    };

    settings = {
      model = {
        provider = "nous";
        default = "deepseek/deepseek-v4-flash";
      };
      approvals = {
        mode = "manual";
      };
      terminal = {
        backend = "docker";
        docker_volumes = [
          "/run/secrets/ssh-private-keys/hermes:/root/.ssh/id_ed25519:ro"
          "/srv/hermes/.ssh/config:/root/.ssh/config:ro"
        ];
      };
      web = {
        backend = "tavily";
      };
      cron = {
        enabled = true;
        wrap_response = true;
        mirror_delivery = true; # Continuable cron: replying to a cron delivery message opens/continues that session!
      };
      discord = {
        require_mention = false; # Respond without requiring @mentions in server channels
        thread_require_mention = false;
        auto_thread = false; # Reply directly inline in channels
        reactions = true;
        history_backfill = true;
        history_backfill_limit = 50;
        allow_mentions = {
          everyone = false;
          roles = false;
          users = true;
          replied_user = true;
        };
      };
      display = {
        tool_progress = "all";
        tool_progress_command = true;
        platforms = {
          discord = {
            reasoning_style = "subtext";
          };
        };
      };
      group_sessions_per_user = true;
      gateway = {
        platforms = {
          discord = {
            extra = {
              allow_from = [
                "1378246341569806377"
              ];
              allow_admin_from = [
                "1378246341569806377"
              ];
            };
          };
        };
      };
    };

    environmentFiles = [
      config.sops.templates."hermes.env".path
    ];

    # Remove static document definition - rely on symlink for live-editable content
  };

  # Add abhay to hermes group so he can read the homelab SSH key
  users.users.abhay.extraGroups = ["hermes"];

  # Ensure hermes system user is in podman/docker groups with subuid/subgid ranges
  users.users.hermes = {
    extraGroups = ["podman" "docker"];
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
  };

  # Path environment, Docker socket binding, and Syncthing live vault links
  systemd.services.hermes-agent = {
    wants = ["podman.socket" "syncthing.service"];
    after = ["podman.socket" "syncthing.service"];
    environment = {
      DOCKER_HOST = "unix:///run/podman/podman.sock";
    };
    path = [
      pkgs.docker-client
      pkgs.podman
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.alejandra
      pkgs.nix
      "/run/current-system/sw"
    ];
    serviceConfig = {
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/chown -R hermes:hermes /srv/hermes"
      ];
      MemoryMax = "1536M";
      MemoryHigh = "1024M";
      CPUQuota = "150%";
    };
  };

  systemd.services.hermes-backend = {
    wants = ["podman.socket" "syncthing.service"];
    after = ["podman.socket" "syncthing.service"];
    environment = {
      DOCKER_HOST = "unix:///run/podman/podman.sock";
    };
  };
}
