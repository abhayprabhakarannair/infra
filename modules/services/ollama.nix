{
  config,
  lib,
  pkgs,
  ...
}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    user = "ollama";
    group = "ollama";
    host = "127.0.0.1";
    port = 11434;
  };

  system.activationScripts.ollama-state-directory = {
    deps = ["createPersistentStorageDirs"];
    text = ''
      if [ -L /var/lib/ollama ] && [ "$(readlink /var/lib/ollama)" = "private/ollama" ]; then
        mkdir -p /persist/var/lib/ollama
        for entry in /var/lib/private/ollama/* /var/lib/private/ollama/.[!.]* /var/lib/private/ollama/..?*; do
          [ -e "$entry" ] || [ -L "$entry" ] || continue
          name="''${entry##*/}"
          if [ ! -e "/persist/var/lib/ollama/$name" ] && [ ! -L "/persist/var/lib/ollama/$name" ]; then
            cp -a -- "$entry" "/persist/var/lib/ollama/$name"
          fi
        done
        rm -f /var/lib/ollama
      fi
    '';
  };
  system.activationScripts.persist-files.deps = lib.mkAfter ["ollama-state-directory"];

  environment.systemPackages = with pkgs; [
    ollama
  ];
}
