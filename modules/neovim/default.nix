{ pkgs, inputs, ... }:

let
  wrappedNeovim = inputs.wrappers.wrappers.neovim.wrap {
    pkgs = pkgs.unstable;
    settings.config_directory = ./.;
    runtimePkgs = with pkgs.unstable; [ nixd ];
  };
in
{
  environment.systemPackages = [
    wrappedNeovim
  ];

}
