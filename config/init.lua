-- Hacky workaround to highlighting issue
local path_fix = "let $PATH=readfile($HOME . \"/.cache/nvim/path\")[0]"
vim.cmd(path_fix)

local function toggle_term(cmd)
  return {
      function() astronvim.toggle_term_cmd(cmd) end,
      desc = "ToggleTerm " .. cmd
  }
end

local function toggle_term_send_n(cmd)
  return {
      function()
        if astronvim.user_terminals[cmd] then
          local line = vim.api.nvim_win_get_cursor(0)[1]
          astronvim.user_terminals[cmd]:send(
              vim.api.nvim_buf_get_lines(0, line - 1, line, true))
          astronvim.user_terminals[cmd]:open()
        else
          vim.api.nvim_echo({
              { cmd .. " terminal is not yet running", "ErrorMsg" }
          }, true, {})
        end
      end,
      desc = "ToggleTerm send to " .. cmd
  }
end

local function toggle_term_send_v(cmd)
  return {
      function()
        if astronvim.user_terminals[cmd] then
          local first_line = vim.api.nvim_buf_get_mark(0, "<")[1]
          local last_line = vim.api.nvim_buf_get_mark(0, ">")[1]
          astronvim.user_terminals[cmd]:send(
              vim.api.nvim_buf_get_lines(0, first_line - 1, last_line,
                  true))
          astronvim.user_terminals[cmd]:open()
        else
          vim.api.nvim_echo({
              { cmd .. " terminal is not yet running", "ErrorMsg" }
          }, true, {})
        end
      end,
      desc = "ToggleTerm send to " .. cmd
  }
end

return {
    mappings = {
        n = {
            ["<leader>tp"] = toggle_term("python3"),
            ["<leader>tsp"] = toggle_term_send_n("python3"),
            ["<leader>tr"] = toggle_term("R"),
            ["<leader>tsr"] = toggle_term_send_n("R"),
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
            ["<leader>e"] = { "<Cmd>Neotree focus<cr>", desc = "Focus Explorer" },
            ["<leader>o"] = {
                "<Cmd>Neotree toggle<cr>",
                desc = "Toggle Explorer"
            }
        },
        v = {
            ["<leader>tp"] = toggle_term_send_v("python3"),
            ["<leader>tr"] = toggle_term_send_v("R"),
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" }
        },
        t = {
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" }
        },
        i = {
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" }
        }
    },
    ["which-key"] = {
        register = {
            n = { ["<leader>ts"] = { name = "Send line to terminal" } },
            v = { ["<leader>t"] = { name = "Send lines to terminal" } }
        },
        marks = false,
        registers = false,
        always_show = false
    },
    polish = function()
      local telescope = require("telescope.builtin")

      -- Open files with git if possible
      vim.api.nvim_set_keymap("n", "<leader>ff", "", {
          callback = function()
            local ok = pcall(telescope.git_files)
            if not ok then telescope.find_files() end
          end
      })
      -- vim.api.nvim_del_keymap("t", "<Esc>")
      vim.api.nvim_set_keymap("t", "<M-w>", "<C-\\><C-N>", { noremap = true })
      local group_id = vim.api.nvim_create_augroup("ToggleTermConfig", {})
      vim.api.nvim_create_autocmd("TermEnter", {
          group = group_id,
          pattern = "term://*toggleterm#*",
          desc = "Map terminal hide for toggleterm terminals",
          callback = function(args)
            vim.api.nvim_buf_set_keymap(args.buf, "n", "<M-q>",
                "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                { noremap = true })
            vim.api.nvim_buf_set_keymap(args.buf, "t", "<M-q>",
                "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                { noremap = true })
            vim.api.nvim_buf_set_keymap(args.buf, "v", "<M-q>",
                "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                { noremap = true })
          end
      })
      -- Clipboard mappings - ^v maps to using the system clipboard, while p defaults to just using vim registers
      vim.api.nvim_set_option("clipboard", "")
      -- vim.api.nvim_set_keymap("i", "<C-v>", "<Esc>\"+pa", { noremap = true })
      -- vim.api.nvim_set_keymap("v", "<C-v>", "s<Esc>\"+p", { noremap = true })

      vim.api.nvim_create_autocmd("FileType", {
          pattern = "markdown",
          desc = "Set Markdown text width",
          callback = function(args)
            vim.api.nvim_buf_set_option(0, "textwidth", 80)
          end
      })

      if vim.api.nvim_eval("exists('g:neovide')") then
        vim.api.nvim_set_option("guifont", "Cascadia Code PL")
        vim.g.neovide_scroll_animation_length = 0
      end
    end,
    plugins = {
        init = {
            { "tpope/vim-surround" }, { "mhinz/vim-crates" }, { "tpope/vim-repeat" },
            { "tpope/vim-characterize" }, { "farmergreg/vim-lastplace" },
            { "junegunn/vim-easy-align" }, { "dccsillag/magma-nvim" },
            { "chrisbra/unicode.vim" }, { "junegunn/fzf" }, { "junegunn/fzf.vim" }
        },
        telescope = {
            pickers = {
                buffers = { sort_mru = true, ignore_current_buffer = true }
            }
        },
        cmp = function(cmp_init)
          local cmp = require("cmp")
          local luasnip = require("luasnip")
          return vim.tbl_deep_extend("force", cmp_init, {
                  mapping = {
                      ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                          cmp.select_next_item()
                        elseif luasnip.expandable() then
                          luasnip.expand()
                        else
                          fallback()
                        end
                      end, { "i", "s" }),
                      ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                          cmp.select_prev_item()
                        elseif luasnip.jumpable( -1) then
                          luasnip.jump( -1)
                        else
                          fallback()
                        end
                      end, { "i", "s" })
                  }
              })
        end,
        ["neo-tree"] = {
            window = {
                mappings = {
                    ["h"] = "prev_source",
                    ["l"] = "next_source",
                    ["Z"] = "expand_all_nodes",
                    ["."] = "nop",
                    ["<bs>"] = "nop"
                }
            },
            filesystem = {
                filtered_items = {
                    visible = false,
                    hide_dotfiles = false,
                    hide_gitignored = true,
                    always_show = { ".gitignore" },
                    hide_by_name = {
                        ".DS_Store", "thumbs.db", "node_modules", "__pycache__",
                        "target", ".git", "Cargo.lock"
                    }
                }
            }
        }
    }
}
