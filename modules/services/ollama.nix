{
  config,
  pkgs,
  ...
}: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    # Ollama has no built-in authentication. Keep the API local unless an
    # authenticated, explicitly scoped proxy is added later.
    host = "127.0.0.1";
    port = 11434;
  };

  environment.systemPackages = with pkgs; [
    ollama
  ];
}
