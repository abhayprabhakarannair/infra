{lib, ...}: {
  colorschemes.kanagawa = {
    enable = true;
  };
    
  globals = {
    mapleader = " ";
    maplocalleader = " ";
    netrw_browse_split = 0;
    netrw_banner = 0;
    netrw_winsize = 25;
  };
  opts = {
    number = true;
    relativenumber = true;

    shiftwidth = 4;
    tabstop = 4;
    softtabstop = 4;
    expandtab = true;
    smartindent = true;

    wrap = false;
    swapfile = false;
    backup = false;
    undofile = true;

    hlsearch = false;
    incsearch = true;

    termguicolors = true;

    scrolloff = 8;
    signcolumn = "yes";
    updatetime = 50;

    ignorecase = true;
    smartcase = true;

    cursorline = true;
  };

}
