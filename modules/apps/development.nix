{ inputs, ... }:
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = false;
    imports = [ inputs.nixvim-config.nixvimModules.default ];
    extraConfigLua = ''
      vim.opt.isfname:append("@-@")
      vim.opt.undodir = os.getenv("HOME") .. "/.nvim/undodir"
    '';
  };
}
