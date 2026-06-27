{config, inputs, ...}:

let
  username = "abhay";
  host = config.networking.hostName;
  devices = import ./devices.nix;
in
{
  sops.secrets."syncthing/gui/password" = { sopsFile = "${inputs.self}/secrets/service-secrets.yaml"; owner = username; };
  sops.secrets."syncthing/${host}/key-pem" = {  sopsFile = "${inputs.self}/secrets/service-secrets.yaml"; owner = username; };
  sops.secrets."syncthing/${host}/cert-pem" = {  sopsFile = "${inputs.self}/secrets/service-secrets.yaml"; owner = username; };

  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/Sync";
    configDir = "/home/${username}/.config/syncthing";
    guiAddress = "0.0.0.0:8384";
    guiPasswordFile = config.sops.secrets."syncthing/gui/password".path;
    key = config.sops.secrets."syncthing/${host}/key-pem".path;
    cert = config.sops.secrets."syncthing/${host}/cert-pem".path;

    settings = {
      devices = {
        "devil" = { id = devices.devil; };
        "oneplus-13" = { id = devices.oneplus13; };
      };
      folders = {
        "Private" = {
          path = "/home/${username}/Sync/Private";
          devices = [ "devil" "oneplus-13" ];
        };
        "Shared" = {
          path = "/home/${username}/Sync/Shared";
          devices = [ "devil" "oneplus-13" ];
        };
      };
    };
  };

  system.activationScripts.syncthing-dirs = {
    text = ''
      mkdir -p /home/${username}/Sync
      mkdir -p /home/${username}/.config/syncthing
      chown -R ${username}:users /home/${username}/Sync /home/${username}/.config/syncthing
    '';
    deps = [];
  };
}
