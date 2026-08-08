{lib, ...}: {
  plugins.mini = {
    enable = true;
    modules = {
      pick = {
        delay = {
          async = 10;
          busy = 50;
        };

        mappings = {
          choose = "<CR>";
          # Open selected file
          choose_in_split = "<A-s>";
          choose_in_vsplit = "<A-v>";
          choose_in_tabpage = "<A-t>";

          # Navigation
          move_down = "<C-n>";
          move_up = "<C-p>";
          # Preview
          toggle_preview = "<Tab>";
          toggle_info = "<S-Tab>";
          # Marks
          mark = "<C-x>";
          mark_all = "<C-a>";
          # Quit
          stop = "<Esc>";
          # Search refinement
          refine = "<C-Space>";
          refine_marked = "<M-Space>";
        };

        options = {
          content_from_bottom = false;
          use_cache = false;
        };
        source = {
          choose = lib.nixvim.mkRaw "nil";
          choose_marked = lib.nixvim.mkRaw "nil";
          cwd = lib.nixvim.mkRaw "nil";
          items = lib.nixvim.mkRaw "nil";
          match = lib.nixvim.mkRaw "nil";
          name = lib.nixvim.mkRaw "nil";
          preview = lib.nixvim.mkRaw "nil";
          show = lib.nixvim.mkRaw "nil";
        };
        window = {
          config = lib.nixvim.mkRaw "nil";
          prompt_caret = "▏";
          prompt_prefix = "> ";
        };
      };
      extra = {};
    };
  };
}
