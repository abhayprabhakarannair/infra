{
  plugins.lsp = {
    enable = true;
    servers = {
      nixd.enable = true;
      lua_ls.enable = true;
      ts_ls.enable = true;
    };
  };
}
