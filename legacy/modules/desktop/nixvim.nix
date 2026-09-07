{inputs, ...}: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    nixpkgs.source = inputs.nixvim.inputs.nixpkgs;
    imports = [
      inputs.nixvim-config.nixvimModules.default
    ];

    extraConfigLua = ''
      vim.opt.isfname:append("@-@")
      vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"
    '';
  };
}
