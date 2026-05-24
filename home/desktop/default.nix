{
  inputs,
  config,
  ...
}: {
  imports = ["${inputs.self}/home/core.nix"];

  # --- ZSH Configuration ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {enable = true;};
    syntaxHighlighting = {enable = true;};
    history = {
      size = 10000;
      path = "$HOME/.zsh_history";
      ignoreAllDups = true;
    };

    shellAliases = {
      ll = "ls -larth";
      nrs = "sudo nixos-rebuild switch --flake ~/Projects/infra#\$(cat /etc/hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/Projects/infra#\$(cat /etc/hostname)";
      ve = "nvim .";
    };

    sessionVariables = {
      EDITOR = "nvim";
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      NIXOS_OZONE_WL = "1";
    };
  };
}
