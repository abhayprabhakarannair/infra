{
  plugins.blink-cmp = {
    enable = true;
    setupLspCapabilities = true;
    settings.sources.default = [
      "lsp"
      "path"
      "snippets"
      "buffer"
      # "copilot"
    ];
    settings.sources = {
    #   copilot = {
    #     async = true;
    #     module = "blink-cmp-copilot";
    #     name = "copilot";
    #     score_offset = 100;
    #   };
    };
  };
  # plugins.blink-cmp-copilot = {
  #   enable = true;
  # };
}
