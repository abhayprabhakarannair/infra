{
  inputs,
  config,
  ...
}: {
  imports = [
    "${inputs.self}/home/core.nix"
    "${inputs.self}/home/desktop/operator.nix"
  ];

  # --- BASH Configuration ---
  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "ls -larth";
      nrs = "sudo nixos-rebuild switch --flake ~/Projects/infra#$(cat /etc/hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/Projects/infra#$(cat /etc/hostname)";
      ve = "nvim .";
    };
  };

  # --- DIR Env ---
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    config = {
      global = {
        hide_env_diff = true;
      };
    };
  };

  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
