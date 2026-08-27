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
  sops.secrets."hermes/discord-mcp-token" = {
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
  # Voice: HA token (device control + HA Assist path) & Telegram bot token (resilient voice channel)
  sops.secrets."hermes/hass-token" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  sops.secrets."hermes/telegram-bot-token" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };
  # Voice: API server bearer key — HA Assist routes conversation to Lucifer via the
  # OpenAI-compatible endpoint (same key configured in HA's OpenAI conversation agent).
  sops.secrets."hermes/api-server-key" = {
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
    "L+ /srv/hermes/.hermes/user_feeds.json - hermes hermes - /srv/hermes/Sync/Lucifer/config/user_feeds.json"
    "L+ /srv/hermes/.hermes/cron/jobs.json - hermes hermes - /srv/hermes/Sync/Lucifer/config/cron_jobs.json"
    "L+ /srv/hermes/.hermes/AGENTS.md - hermes hermes - /srv/hermes/Sync/Lucifer/AGENTS.md"
    "d /srv/hermes/mem0_qdrant 0755 root root - -"
    "d /srv/hermes/Sync/Lucifer/memory 0755 hermes hermes - -"
    "d /srv/hermes/Sync/Lucifer/config 0755 hermes hermes - -"
    "d /srv/hermes/Sync/Lucifer/misc 0755 hermes hermes - -"
  ];

  # Construct the runtime environment file from sops placeholders
  sops.templates."hermes.env" = {
    content = ''
      GEMINI_API_KEY=${config.sops.placeholder."hermes/gemini-api-key"}
      # mem0 OSS points its openai provider at Gemini's OpenAI-compatible endpoint;
      # it reads the key from OPENAI_API_KEY. Reuses the existing Gemini secret.
      OPENAI_API_KEY=${config.sops.placeholder."hermes/gemini-api-key"}
      DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes/discord-bot-token"}
      DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes/discord-allowed-users"}
      DISCORD_MCP_TOKEN=${config.sops.placeholder."hermes/discord-mcp-token"}
      DISCORD_HOME_CHANNEL=1542031236082565140
      DISCORD_HOME_CHANNEL_NAME="#home"
      DISCORD_REQUIRE_MENTION=false
      DISCORD_THREAD_REQUIRE_MENTION=false
      DISCORD_AUTO_THREAD=false
      # Voice: Home Assistant (device control + HA Assist) & Telegram (resilient voice DM)
      HASS_TOKEN=${config.sops.placeholder."hermes/hass-token"}
      HASS_URL=https://home.iamabhay.fyi
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes/telegram-bot-token"}
      # API server: OpenAI-compatible endpoint so HA Assist on the phone routes to
      # Lucifer (the agent), not HA's stock conversation agent. Binds 0.0.0.0 — the
      # public NIC stays firewalled (8642 not in allowedTCPPorts), tailnet is a trusted
      # interface, so only old-devil/HA can reach it via http://lucifer:8642/v1.
      API_SERVER_ENABLED=true
      API_SERVER_KEY=${config.sops.placeholder."hermes/api-server-key"}
      API_SERVER_HOST=0.0.0.0
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
    extraDependencyGroups = ["messaging" "mem0" "voice"]; # voice = faster-whisper local STT + sounddevice
    stateDir = "/srv/hermes";
    workingDirectory = "/srv/hermes/workspace";
    # Discord voice: discord.py loads libopus via ctypes.util.find_library('opus'),
    # whose gcc -l probe ignores LD_LIBRARY_PATH on NixOS (returns None -> voice
    # disabled: "Opus codec not found"). This plugin preloads the codec explicitly
    # at gateway startup via discord.opus.load_opus(). Verified on lucifer's live
    # env: load_opus(store path) -> is_loaded() True.
    extraPlugins = [
      (pkgs.runCommand "discord-opus-preload" {} ''
        mkdir -p $out
        substitute ${./discord-opus-preload/__init__.py} $out/__init__.py \
          --replace '@LIBOPUS@' '${pkgs.libopus}/lib/libopus.so.0'
        cp ${./discord-opus-preload/plugin.yaml} $out/plugin.yaml
      '')
    ];

    backend = {
      mode = "dashboard";
      host = "0.0.0.0";
      port = 9000;
    };

    settings = {
      # discord-opus-preload is a standalone (user) plugin, which Hermes treats
      # as opt-in: it is discovered but NOT loaded unless listed here. Bundled
      # platform/backend plugins auto-load; standalone/user plugins do not.
      # Without this, discord.py never preloads libopus and Discord voice stays
      # disabled ("Opus codec not found").
      plugins = {
        enabled = ["discord-opus-preload"];
      };
      model = {
        provider = "nous";
        default = "deepseek/deepseek-v4-flash";
      };
      # Mem0 external memory provider (OSS, Gemini via OPENAI_API_KEY, local qdrant)
      memory = {
        provider = "mem0";
      };
      approvals = {
        mode = "manual";
      };
      terminal = {
        backend = "docker";
        docker_volumes = [
          "/run/secrets/ssh-private-keys/hermes:/root/.ssh/id_ed25519:ro"
          "/srv/hermes/.ssh/config:/root/.ssh/config:ro"
          # Live Syncthing vault: read/write access to SOUL.md, AGENTS.md, user_feeds.json, cron_jobs.json
          "/srv/hermes/Sync/Lucifer:/root/.hermes/vault"
        ];
      };
      web = {
        backend = "tavily";
      };
      # Voice: local STT (faster-whisper) + TTS via Nous Portal (OpenAI TTS through Tool Gateway)
      stt = {
        enabled = true;
        provider = "local";
        local.model = "base";
      };
      tts = {
        provider = "openai"; # Nous Portal Tool Gateway routes OpenAI TTS; no separate key needed
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
          telegram = {
            extra = {
              allow_from = [
                "264775856"
              ];
              allow_admin_from = [
                "264775856"
              ];
            };
          };
          homeassistant = {
            enabled = true;
            extra = {
              # React to meaningful home state changes; device control tools activate via HASS_TOKEN
              watch_domains = [
                "climate"
                "binary_sensor"
                "alarm_control_panel"
                "light"
              ];
              cooldown_seconds = 30;
            };
          };
          api_server = {
            extra = {
              # Honor the "hermes-agent" model name HA sends (bare model, no provider
              # field) instead of silently falling back to the gateway default model.
              direct_model_requests = true;
            };
          };
        };
      };
    };

    environmentFiles = [
      config.sops.templates."hermes.env".path
    ];

    # Mem0 OSS memory provider config (non-secret). Key comes from OPENAI_API_KEY env.
    # LLM/embedder ride Gemini's OpenAI-compatible endpoint; vectors go to local qdrant.
    # Not enabled yet: set settings.memory.provider="mem0" at activation (credit gate).
    hermesHomeFiles."mem0.json" = ''
      {
        "mode": "oss",
        "user_id": "abhay",
        "agent_id": "hermes",
        "oss": {
          "llm": {
            "provider": "openai",
            "config": {
              "model": "gemini-3.6-flash",
              "openai_base_url": "https://generativelanguage.googleapis.com/v1beta/openai/"
            }
          },
          "embedder": {
            "provider": "openai",
            "config": {
              "model": "gemini-embedding-001",
              "openai_base_url": "https://generativelanguage.googleapis.com/v1beta/openai/",
              "embedding_dims": 3072
            }
          },
          "vector_store": {
            "provider": "qdrant",
            "config": {
              "host": "localhost",
              "port": 6333,
              "collection_name": "mem0",
              "embedding_model_dims": 3072
            }
          }
        }
      }
    '';

    # Mazikeen — Discord housekeeper via MCP (HTTP transport, localhost)
    mcpServers = {
      mazikeen = {
        url = "http://127.0.0.1:8000/mcp";
        headers = {
          Authorization = "Bot \${DISCORD_MCP_TOKEN}";
        };
        timeout = 60;
      };
    };

    # Remove static document definition - rely on symlink for live-editable content
  };

  # Qdrant vector DB — mem0's vector store (server mode; localhost only, data on /srv).
  virtualisation.oci-containers.containers.qdrant = {
    image = "qdrant/qdrant:latest@sha256:6c0652f8d6925b22f2f6f0e0a5365a6c9dbc8768bd6e70ccc1cdc14847e452a0";
    autoRemoveOnStop = false;
    ports = ["127.0.0.1:6333:6333"];
    volumes = ["/srv/hermes/mem0_qdrant:/qdrant/storage"];
    extraOptions = ["--restart=always"];
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
      # discord.py loads libopus via ctypes.util.find_library(), which searches
      # LD_LIBRARY_PATH — without this it can't discover the codec and Discord
      # voice playback is disabled ("Opus codec not found").
      LD_LIBRARY_PATH = "${pkgs.libopus}/lib:${pkgs.opusfile}/lib";
    };
    path = [
      pkgs.docker-client
      pkgs.podman
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.alejandra
      pkgs.nix
      pkgs.ffmpeg
      pkgs.libopus
      pkgs.portaudio
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

  # Export mem0 memories to plain-text JSONL in the Syncthing vault (Design A).
  # Zero LLM tokens: reads qdrant directly, atomic full overwrite (regenerated each run).
  systemd.services.mem0-export = {
    serviceConfig = {
      Type = "oneshot";
      User = "hermes";
      Group = "hermes";
    };
    path = [pkgs.coreutils];
    script = ''
      ${pkgs.python312.withPackages (ps: [ps.qdrant-client])}/bin/python3 - <<'PY'
      import json, pathlib
      from qdrant_client import QdrantClient
      out = pathlib.Path("/srv/hermes/Sync/Lucifer/memory/mem0.jsonl")
      try:
          client = QdrantClient(url="http://localhost:6333")
      except Exception:
          raise SystemExit(0)  # qdrant down: keep last good snapshot
      if not client.collection_exists("mem0"):
          out.write_text("")
          raise SystemExit(0)
      rows, offset = [], None
      while True:
          pts, nxt = client.scroll(collection_name="mem0", limit=100,
                                   with_payload=True, with_vectors=False, offset=offset)
          for pt in pts:
              p = pt.payload or {}
              rows.append({"id": str(pt.id), "memory": p.get("data", ""),
                           "metadata": {k: v for k, v in p.items()
                                        if k not in ("data", "text_lemmatized")}})
          if nxt is None:
              break
          offset = nxt
      tmp = out.with_suffix(".jsonl.tmp")
      tmp.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + ("\n" if rows else ""))
      tmp.rename(out)
      PY
    '';
  };

  systemd.timers.mem0-export = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
      AccuracySec = "1min";
    };
  };

  # Mazikeen — Discord housekeeper MCP server (HTTP, localhost only)
  systemd.services.discord-mcp = {
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    environment = {
      MCP_HOST = "127.0.0.1";
      MCP_PORT = "8000";
    };
    serviceConfig = {
      ExecStart = "${pkgs.discord-mcp}/bin/discord-mcp";
      User = "hermes";
      Group = "hermes";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
