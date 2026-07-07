{pkgs, inputs, ...}:

{


  sops.secrets."ups-password" = {
    sopsFile = "${inputs.self}/secrets/service-secrets.yaml";
  };

  environment.systemPackages = with pkgs; [
    nut
  ];


power.ups = {
  enable = true;
  mode = "netclient"; # MUST be netclient
  upsmon.monitor = {
    myups = {
      user = "monitorUser";
      passwordFile = "/run/secrets/ups-password"; # Must match the user created on the server
      system = "myups@devil"; # Point to the Server's IP
    };
  };
};
}
