{inputs, ...}: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    imports = [
      "${inputs.self}/modules/neovim"
    ];

    extraConfigLua = ''
      vim.opt.isfname:append("@-@")
      vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"
    '';
  };
}
