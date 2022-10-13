local terms = require("toggleterm.terminal")
local cmp = require("cmp")
local luasnip = require("luasnip")

function vim.g.RemoteOpen(pwd, args)
  local terminals = terms.get_all()
  local open = {}
  for _, t in pairs(terminals) do
    if t:is_open() then
      t:close()
      table.insert(open, t)
    end
  end
  local file_list = {}
  -- local open = toggleterm_ui.find_open_windows()
  -- if open then toggleterm.toggle_all(true) end
  local wait = false
  local is_empty = true
  for file in string.gmatch(args, "[^%s]+") do
    if string.sub(file, 1, 1) == "-" then
      -- Is arg
      if file == "--wait" then
        wait = true
      else
        vim.cmd("echom 'Unknown arg: `" .. file .. "`'")
      end
    elseif string.sub(file, 1, 1) == "/" then
      -- Is absolute
      vim.cmd('edit ' .. file)
      file_list[vim.api.nvim_get_current_buf()] = true
      is_empty = false
    else
      -- Is relative
      vim.cmd('edit ' .. pwd .. '/' .. file)
      file_list[vim.api.nvim_get_current_buf()] = true
      is_empty = false
    end
  end
  if not wait or is_empty then
    vim.defer_fn(function()
      for _, t in pairs(open) do
        t:send({ "", "NVIM_EDITOR_CLOSE" }, false)
      end
    end, 20)
  else
    for buf, _ in pairs(file_list) do
      vim.api.nvim_create_autocmd({ "BufDelete" }, {
        buffer = buf,
        callback = function(ev)
          file_list[ev.buf] = false
          local last = true
          for _, v in pairs(file_list) do
            if v then last = false end
          end
          if last then
            for _, t in pairs(open) do
              t:open()
              t:send({ "", "NVIM_EDITOR_CLOSE" }, false)
            end
          end
        end,
        once = true,
      })
    end
  end
  return ""
end

local telescope = require("telescope.builtin")

local function toggle_term(cmd)
  return { function() astronvim.toggle_term_cmd(cmd) end, desc = "ToggleTerm " .. cmd }
end

local function toggle_term_send_n(cmd)
  return { function()
    if astronvim.user_terminals[cmd] then
      local line = vim.api.nvim_win_get_cursor(0)[1]
      astronvim.user_terminals[cmd]:send(vim.api.nvim_buf_get_lines(0, line - 1, line, true))
      astronvim.user_terminals[cmd]:open()
    else
      vim.api.nvim_echo({ { cmd .. " terminal is not yet running", "ErrorMsg" } }, true, {})
    end
  end, desc = "ToggleTerm send to " .. cmd }
end

local function toggle_term_send_v(cmd)
  return { function()
    if astronvim.user_terminals[cmd] then
      local first_line = vim.api.nvim_buf_get_mark(0, "<")[1]
      local last_line = vim.api.nvim_buf_get_mark(0, ">")[1]
      astronvim.user_terminals[cmd]:send(vim.api.nvim_buf_get_lines(0, first_line - 1, last_line, true))
      astronvim.user_terminals[cmd]:open()
    else
      vim.api.nvim_echo({ { cmd .. " terminal is not yet running", "ErrorMsg" } }, true, {})
    end
  end, desc = "ToggleTerm send to " .. cmd }
end

return {
  mappings = {
    n = {
      ["<leader>tp"] = toggle_term("python3"),
      ["<leader>tsp"] = toggle_term_send_n("python3"),
      ["<leader>tr"] = toggle_term("R"),
      ["<leader>tsr"] = toggle_term_send_n("R"),
      ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
    },
    v = {
      ["<leader>tp"] = toggle_term_send_v("python3"),
      ["<leader>tr"] = toggle_term_send_v("R"),
      ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
    },
    t = {
      ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
    },
    i = {
      ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
    },
  },
  ["which-key"] = {
    register = {
      n = {
        ["<leader>ts"] = { name = "Send line to terminal" },
      },
      v = {
        ["<leader>t"] = { name = "Send lines to terminal" },
      },
    },
    marks = false,
    registers = false,
    always_show = false,
  },
  polish = function()
    -- Open files with git if possible
    vim.api.nvim_set_keymap("n", "<leader>ff", "", {
      callback = function()
        local ok = pcall(telescope.git_files)
        if not ok then telescope.find_files() end
      end,
    })
    -- vim.api.nvim_del_keymap("t", "<Esc>")
    vim.api.nvim_set_keymap("t", "<M-w>", "<C-\\><C-N>", { noremap = true, })
    local group_id = vim.api.nvim_create_augroup("ToggleTermConfig", {})
    vim.api.nvim_create_autocmd("TermEnter", {
      group = group_id,
      pattern = "term://*toggleterm#*",
      desc = "Map terminal hide for toggleterm terminals",
      callback = function(args)
        vim.api.nvim_buf_set_keymap(args.buf, "n", "<M-q>", "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
          { noremap = true })
        vim.api.nvim_buf_set_keymap(args.buf, "t", "<M-q>", "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
          { noremap = true })
        vim.api.nvim_buf_set_keymap(args.buf, "v", "<M-q>", "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
          { noremap = true })
      end,
    })
    -- Clipboard mappings - ^v maps to using the system clipboard, while p defaults to just using vim registers
    vim.api.nvim_set_option("clipboard", "")
    vim.api.nvim_set_keymap("i", "<C-v>", "<Esc>\"+pa", { noremap = true, })
    vim.api.nvim_set_keymap("v", "<C-v>", "s<Esc>\"+p", { noremap = true, })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      desc = "Set Markdown text width",
      callback = function(args)
        vim.api.nvim_buf_set_option(0, "textwidth", 80)
      end,
    })
  end,
  plugins = {
    init = {
      { "tpope/vim-surround" },
      { "mhinz/vim-crates" },
      { "tpope/vim-repeat" },
      { "tpope/vim-characterize" },
      { "farmergreg/vim-lastplace" },
      { "junegunn/vim-easy-align" },
      { "dccsillag/magma-nvim" },
    },
    telescope = { pickers = { buffers = { sort_mru = true, ignore_current_buffer = true } } },
    cmp = {
      mapping = {
        ["<Tab>"] = cmp.mapping(function(fallback)
          vim.cmd("echo 'Pressed Tab'")
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expandable() then
            luasnip.expand()
            -- elseif luasnip.expand_or_jumpable() then
            --   luasnip.expand_or_jump()
          else
            fallback()
          end
        end, {
          "i",
          "s",
        }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, {
          "i",
          "s",
        }),
      },
    },
    ["neo-tree"] = {
      window = {
        mappings = {
          ["h"] = "prev_source",
          ["l"] = "next_source",
          ["Z"] = "expand_all_nodes",
        },
      },
      filesystem = {
        filtered_items = {
          visible = false,
          hide_dotfiles = false,
          hide_gitignored = true,
          always_show = { ".gitignore" },
          hide_by_name = {
            ".DS_Store",
            "thumbs.db",
            "node_modules",
            "__pycache__",
            "target",
            ".git",
            "Cargo.lock",
          },
        }
      }
    }
  }
}
