{pkgs}:
pkgs.writeShellApplication {
  name = "install-infra";

  # Inject dependencies here. These are added to the script's PATH automatically.
  runtimeInputs = [
    pkgs.nixos-anywhere
    pkgs.openssh
  ];

  # Read the bash file from disk
  text = builtins.readFile ./install-infra.sh;
}
