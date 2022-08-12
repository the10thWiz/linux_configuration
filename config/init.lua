
local toggleterm = require("toggleterm")
local toggleterm_ui = require("toggleterm.ui")
local terms = require("toggleterm.terminal")

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
        t:send({"", "NVIM_EDITOR_CLOSE"}, false)
      end
    end, 20)
  else
    for buf, _ in pairs(file_list) do
      vim.api.nvim_create_autocmd({"BufDelete"}, {
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
              t:send({"", "NVIM_EDITOR_CLOSE"}, false)
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

return {
  polish = function()
    -- Open files with git if possible
    vim.api.nvim_set_keymap("n", "<leader>ff", "", {
      callback = function()
        local ok = pcall(telescope.git_files)
        if not ok then telescope.find_files() end
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
    },
    telescope = { pickers = { buffers = { sort_mru = true, ignore_current_buffer = true } } },
  }
}

