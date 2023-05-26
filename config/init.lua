local function fixEnviron()
    local environ = vim.fn.environ()
    local checked_paths = {
        environ["HOME"] .. "/.cargo/bin", environ["HOME"] .. "/.local/bin"
    }
    for _, path in pairs(checked_paths) do
        if string.find(environ["PATH"], path) == nil then
            vim.cmd(string.format("let $PATH.= \":%s\"", path))
        end
    end
end

fixEnviron()

local function toggle_term(cmd)
    return {
        function() require("astronvim").toggle_term_cmd(cmd) end,
        desc = "ToggleTerm " .. cmd
    }
end
local function toggle_term_send_n(cmd)
    return {
        function()
            local astronvim = require("astronvim")
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
            local astronvim = require("astronvim")
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

vim.api.nvim_set_var("nvim_ghost_use_script", 1)
vim.api.nvim_set_var("nvim_ghost_python_executable", "/usr/bin/python3")
vim.api.nvim_set_option("clipboard", "")
-- This should be set in the later mappings but it is not working for some reason
vim.api.nvim_set_keymap("i", "<C-l>", "copilot#Accept('')", { expr = true, noremap = true })

return {
    polish = function()
        -- vim.api.nvim_del_keymap("t", "<Esc>")
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

        local urls = {}
        urls["*stackoverflow.com"] = "markdown"
        urls["*codechef.com"] = "python"
        local group = vim.api.nvim_create_augroup(
            "nvim_ghost_user_autocommands", { clear = false })
        for url, filetype in pairs(urls) do
            vim.api.nvim_create_autocmd("User", {
                group = group,
                pattern = url,
                command = "setfiletype " .. filetype
            })
        end
    end,
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
            },
            ["<leader>ff"] = {
                function()
                    local telescope = require("telescope.builtin")
                    local ok = pcall(telescope.git_files)
                    if not ok then telescope.find_files() end
                end,
                desc = "Find files"
            }
        },
        v = {
            ["<leader>tp"] = toggle_term_send_v("python3"),
            ["<leader>tr"] = toggle_term_send_v("R"),
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
        },
        t = {
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
            ["<M-w>"] = {
                "<C-\\><C-N>",
                desc = "Terminal normal mode",
                noremap = true
            },
        },
        i = {
            ["<C-v>"] = { "<Esc>\"+pa", noremap = true, desc = "Paste from system clipboard" },
            ["<C-\\>"] = { "<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal" },
        }
    },
    lsp = {
        formatting = { format_on_save = false },
        config = {
            ["rust_analyzer"] = {
                settings = {
                    ["rust-analyzer"] = {
                        cargo = { features = "all" },
                        check = { features = "all" }
                    }
                }
            },
            ["lua_ls"] = {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        diagnostics = { globals = { "vim", "require" } },
                        workspace = { library = vim.api.nvim_get_runtime_file("", true) },
                        telemetry = { enable = false },
                    },
                },
            }
        }
    },
    plugins = {
        { "tpope/vim-surround",       lazy = false },
        { "mhinz/vim-crates",         lazy = false },
        { "tpope/vim-repeat",         lazy = false },
        { "tpope/vim-characterize",   lazy = false },
        { "farmergreg/vim-lastplace", lazy = false },
        { "junegunn/vim-easy-align",  lazy = false },
        { "dccsillag/magma-nvim",     lazy = false },
        { "subnut/nvim-ghost.nvim",   lazy = false },
        { "github/copilot.vim",       lazy = false },
        { "junegunn/fzf",             lazy = false },
        { "junegunn/fzf.vim",         lazy = false },
        { "chrisbra/unicode.vim",     lazy = false },
        {
            "hrsh7th/nvim-cmp",
            opts = function(_, opts)
                local cmp = require("cmp")
                local luasnip = require("luasnip")
                -- modify the mapping part of the table
                opts.mapping["<Tab>"] = cmp.mapping(function(fallback)
                    -- vim.cmd("echo Pressed Tab")
                    if cmp.visible() then
                        cmp.select_next_item()
                    elseif luasnip.expandable() then
                        luasnip.expand()
                        -- elseif luasnip.expand_or_jumpable() then
                        --   luasnip.expand_or_jump()
                    else
                        fallback()
                    end
                end, { "i", "s" })
                opts.mapping["<S-Tab>"] =
                    cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" })
                return opts
            end
        }, {
            "nvim-neo-tree/neo-tree.nvim",
            opts = function(_, opts)
                opts.window.mappings["h"] = "prev_source"
                opts.window.mappings["l"] = "next_source"
                opts.window.mappings["Z"] = "expand_all_nodes"
                opts.window.mappings["."] = "nop"
                opts.window.mappings["<bs>"] = "nop"
                if opts.filesystem.filtered_items == nil then
                    opts.filesystem.filtered_items = {}
                end
                opts.filesystem.filtered_items.visible = false
                opts.filesystem.filtered_items.hide_dotfiles = false
                opts.filesystem.filtered_items.hide_gitignored = true
                opts.filesystem.filtered_items.always_show = { ".gitignore" }
                opts.filesystem.filtered_items.hide_by_name = {
                    ".DS_Store", "thumbs.db", "node_modules", "__pycache__",
                    "target", ".git", "Cargo.lock"
                }
                return opts
            end
        }, {
            "nvim-telescope/telescope.nvim",
            opts = function(_, opts)
                if opts.pickers == nil then
                    opts.pickers = { buffers = {} }
                elseif opts.pickers.buffers == nil then
                    opts.pickers.buffers = {}
                end
                opts.pickers.buffers.sort_mru = true
                opts.pickers.buffers.ignore_current_buffer = true
                return opts
            end
        }, {
            "folke/which-key.nvim",
            opts = function(_, opts)
                opts.plugins = {
                    marks = false,
                    registers = false,
                    spelling = false
                }
                if opts.register == nil then
                    opts.register = { n = {}, v = {} }
                end
                opts.register.n["<leader>ts"] = { name = "Send line to terminal" }
                opts.register.n["<leader>t"] = { name = "Send lines to terminal" }
                return opts
            end
        }
    }
}
