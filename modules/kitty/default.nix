{ pkgs, inputs, ... }:

let
  wrappedKitty = inputs.wrappers.wrappers.kitty.wrap {
    pkgs = pkgs.unstable;
    extraConfig = builtins.readFile ./kitty.conf;
  };
  kittyXtermFallback = pkgs.writeShellScriptBin "xterm" ''
    exec ${wrappedKitty}/bin/kitty "$@"
  '';
in
{
  environment.systemPackages = [
    wrappedKitty
    kittyXtermFallback
  ];
}
