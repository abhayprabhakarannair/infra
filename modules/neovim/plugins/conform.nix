{
  plugins.conform-nvim = {
    enable = true;

    settings = {
      formatters_by_ft = {
        nix = ["alejandra"];
        lua = ["stylua"];

        typescript = ["prettier"];
        typescriptreact = ["prettier"];
        javascript = ["prettier"];
        javascriptreact = ["prettier"];
        json = ["prettier"];
      };
    };
  };
}
