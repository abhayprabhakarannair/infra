"""Discord Opus preload plugin.

discord.py loads libopus via ``ctypes.util.find_library('opus')``. On NixOS
that resolves through a ``gcc -l`` probe which ignores LD_LIBRARY_PATH, so it
returns None and Discord voice playback is disabled ("Opus codec not found —
voice channel playback disabled"). Confirmed on lucifer:

    find_library('opus') -> None        # gcc probe ignores LD_LIBRARY_PATH
    direct CDLL of libopus.so.0 -> OK   # explicit path always works

This plugin preloads the codec explicitly via ``discord.opus.load_opus()`` at
gateway startup (before the Discord adapter connects), using the absolute nix
store path baked in at build time, with an LD_LIBRARY_PATH scan as fallback.
"""

import os

# Absolute store path substituted at build time (see hermes-agent.nix).
_LIBOPUS = "@LIBOPUS@"


def _preload_opus() -> None:
    try:
        import discord.opus as opus

        if opus.is_loaded():
            return

        candidates = []
        if _LIBOPUS.startswith("/nix/store/"):
            candidates.append(_LIBOPUS)
        # Fallback: scan LD_LIBRARY_PATH for libopus.so*
        for lp in os.environ.get("LD_LIBRARY_PATH", "").split(":"):
            if not lp:
                continue
            for name in ("libopus.so.0", "libopus.so"):
                cand = os.path.join(lp, name)
                if os.path.isfile(cand):
                    candidates.append(cand)
                    break

        for cand in candidates:
            try:
                opus.load_opus(cand)
                return
            except Exception:
                continue
        # Last resort: default discovery (may still fail on NixOS).
        opus._load_default()
    except Exception:
        pass  # never crash gateway startup if opus is unavailable


_preload_opus()


def register(ctx) -> dict:
    # Preload already ran at import time; nothing to register.
    return {}
