{
  keymaps = [
    {
      mode = ["n" "v"];
      key = "<left>";
      action = "<cmd>echo 'Use h to move!!'<CR>";
    }
    {
      mode = ["n" "v"];
      key = "<right>";
      action = "<cmd>echo 'Use l to move!!'<CR>";
    }
    {
      mode = ["n" "v"];
      key = "<up>";
      action = "<cmd>echo 'Use k to move!!'<CR>";
    }
    {
      mode = ["n" "v"];
      key = "<down>";
      action = "<cmd>echo 'Use j to move!!'<CR>";
    }

    # Clipboard
    {
      mode = ["n" "v"];
      key = "<leader>y";
      action = "\"+y";
    }
    {
      mode = ["n" "v"];
      key = "<leader>p";
      action = "\"+p";
    }

    # Move selected text
    {
      mode = "v";
      key = "J";
      action = ":m '>+1<CR>gv=gv";
    }
    {
      mode = "v";
      key = "K";
      action = ":m '<-2<CR>gv=gv";
    }
    {
      mode = "n";
      key = "<leader>ff";
      action.__raw = ''
        function()
          require("conform").format({
             async = true,
             lsp_fallback = true,
          })
        end
      '';
      options.desc = "Format buffer";
    }
    {
      mode = "n";
      key = "<leader>sf";
      action.__raw = "function() MiniPick.builtin.files() end";
    }
    {
      mode = "n";
      key = "<leader>sb";
      action.__raw = "function() MiniPick.builtin.buffers() end";
    }
    {
      mode = "n";
      key = "<leader>sh";
      action.__raw = "function() MiniPick.builtin.help() end";
    }
    {
      mode = "n";
      key = "<leader>sg";
      action.__raw = "function() MiniPick.builtin.grep_live() end";
      options.desc = "Live grep";
    }
    {
      mode = "n";
      key = "<leader>sw";
      action.__raw = ''
        function()
          MiniPick.builtin.grep({
            pattern = vim.fn.expand("<cword>")
          })
        end
      '';
      options.desc = "Find word under cursor";
    }
    {
      mode = "n";
      key = "<leader>sr";
      action.__raw = "function() MiniPick.builtin.resume() end";
      options.desc = "Resume picker";
    }
    {
      mode = "n";
      key = "<leader>ss";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'document_symbol' }) end";
    }
    {
      mode = "n";
      key = "<leader>sS";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'workspace_symbol' }) end";
    }
    {
      mode = "n";
      key = "<leader>sd";
      action.__raw = "function() MiniExtra.pickers.diagnostic() end";
    }
    {
      mode = "n";
      key = "<leader>rn";
      action.__raw = "function() vim.lsp.buf.rename() end";
    }
    {
      mode = "n";
      key = "<leader>ca";
      action.__raw = "function() vim.lsp.buf.code_action() end";
    }
    {
      mode = "n";
      key = "<leader>di";
      action.__raw = "function() vim.diagnostic.open_float() end";
    }

    {
      mode = "n";
      key = "gd";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'definition' }) end";
      options.desc = "Go to definition";
    }
    {
      mode = "n";
      key = "gr";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'references' }) end";
      options.desc = "Find references";
    }
    {
      mode = "n";
      key = "gi";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'implementation' }) end";
      options.desc = "Find implementations";
    }
    {
      mode = "n";
      key = "gt";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'type_definition' }) end";
      options.desc = "Type definitions";
    }
    {
      mode = "n";
      key = "<leader>ds";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'document_symbol' }) end";
      options.desc = "Document symbols";
    }
    {
      mode = "n";
      key = "<leader>ws";
      action.__raw = "function() MiniExtra.pickers.lsp({ scope = 'workspace_symbol' }) end";
      options.desc = "Workspace symbols";
    }
    {
      mode = "n";
      key = "<leader>dq";
      action.__raw = "function() MiniExtra.pickers.diagnostic() end";
      options.desc = "Diagnostics";
    }
  ];
}
