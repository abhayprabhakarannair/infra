{
  config,
  pkgs,
  ...
}: {
  services.alloy = {
    enable = true;
    configPath = pkgs.writeText "alloy-node.river" (
      builtins.replaceStrings
      ["__HOSTNAME__"]
      [config.networking.hostName]
      (builtins.readFile ./alloy-node.river)
    );
  };

  systemd.services.alloy = {
    serviceConfig = {
      User = pkgs.lib.mkForce "root";
      Group = pkgs.lib.mkForce "root";
    };
  };
}
