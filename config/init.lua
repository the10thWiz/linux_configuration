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

local debug_level = 8
local function debug(lvl, ...)
    if lvl > debug_level then
        return
    end
    local str = ""
    for _, val in pairs({ ... }) do
        str = str .. val
    end
    vim.cmd("echo '"..str.."'")
end

local function split(s, pat)
    local ret = {}
    local cur = 0
    local count = 0
    while true do
        local start = string.find(s, pat, cur)
        if start == nil then
            table.insert(ret, string.sub(s, cur))
            return ret
        end
        table.insert(ret, string.sub(s, cur, start))
        cur = start + string.len(pat)
        count = count + 1
        if count > 20 then return ret end
    end
end

local mk_exec_obj = {
    blocks = {},
    namespace = vim.api.nvim_create_namespace("markdown_codeblock_executer")
}
local function markdown_codeblock_executer()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    mk_exec_obj.blocks = {}
    local cur_block = {}
    for idx, line in pairs(lines) do
        if string.find(line, "```") == 1 then
            if cur_block.started == nil then
                cur_block.start_idx = idx + 1
                cur_block.started = "```"
                cur_block.params = split(string.sub(line, 3), ",")
                debug(10, cur_block.start_idx, " Blocks start")
            else
                cur_block.end_idx = idx - 1
                debug(10, cur_block.end_idx, " Blocks end")
                table.insert(mk_exec_obj.blocks, cur_block)
                cur_block = {}
            end
        elseif string.find(line, "    ") == 1 and cur_block.started ~= "```" then
            cur_block.started = "    "
            if cur_block.start_idx == nil then
                cur_block.start_idx = idx
                cur_block.params = {}
                debug(10, cur_block.start_idx, " Blocks start")
            end
            cur_block.end_idx = idx
        elseif cur_block.started == "    " then
            debug(cur_block.end_idx, " Blocks end")
            table.insert(mk_exec_obj.blocks, cur_block)
            cur_block = {}
        end
    end
    debug(4, #mk_exec_obj.blocks, " Blocks found")
    -- TODO: begin execution of blocks, and put results in an extmark
end

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
                    {cmd .. " terminal is not yet running", "ErrorMsg"}
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
                    {cmd .. " terminal is not yet running", "ErrorMsg"}
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
-- vim.api.nvim_set_keymap("i", "<C-l>", "copilot#Accept('')", { expr = true, noremap = true })
-- When using copilot.lua, we can actually integrate it into nvim-cmp, the normal completion engine

return {
    polish = function()
        vim.g.mk_exec = markdown_codeblock_executer;
        vim.g.split_s = split;
        -- vim.api.nvim_del_keymap("t", "<Esc>")
        local group_id = vim.api.nvim_create_augroup("ToggleTermConfig", {})
        vim.api.nvim_create_autocmd("TermEnter", {
            group = group_id,
            pattern = "term://*toggleterm#*",
            desc = "Map terminal hide for toggleterm terminals",
            callback = function(args)
                vim.api.nvim_buf_set_keymap(args.buf, "n", "<M-q>",
                                            "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                                            {noremap = true})
                vim.api.nvim_buf_set_keymap(args.buf, "t", "<M-q>",
                                            "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                                            {noremap = true})
                vim.api.nvim_buf_set_keymap(args.buf, "v", "<M-q>",
                                            "<Cmd>exe b:toggle_number . 'ToggleTerm'<cr>",
                                            {noremap = true})
            end
        })

        -- autocmd FileType markdown set textwidth=80
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            desc = "Set Markdown text width",
            callback = function(args)
                vim.api.nvim_buf_set_option(0, "textwidth", 80)
            end
        })

        -- autocmd FileType gitcommit,gitrebase,gitconfig set bufhidden=delete
        vim.api.nvim_create_user_command('GitWrite', function()
            vim.cmd("write | bdelete | ToggleTerm")
        end, {})
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "gitcommit,gitrebase,gitconfig",
            desc = "git buffers get deleted when hidden",
            callback = function(args)
                vim.api.nvim_buf_set_option(0, "bufhidden", "delete")
                -- TODO: maybe locally override close (<leader>c) to also trigger toggleterm?
                vim.api.nvim_buf_set_keymap(0, "n", "<leader>c",
                                            "<Cmd>bd<cr><Cmd>ToggleTerm<cr>", {})
                vim.cmd("cnoreabbrev <buffer> x GitWrite")
                vim.cmd("cnoreabbrev <buffer> wq GitWrite")
            end
        })

        if vim.api.nvim_eval("exists('g:neovide')") then
            vim.api.nvim_set_option("guifont", "CaskaydiaCove Nerd Font Mono")
            vim.g.neovide_scroll_animation_length = 0
        end

        vim.api.nvim_create_user_command("ToggleTermCloseAll", function()
            require("toggleterm").toggle_all("close")
        end, {})
        vim.cmd("aunmenu PopUp.How-to\\ disable\\ mouse | aunmenu PopUp.-1-")

        vim.env.GIT_EDITOR = "nvr -cc 'ToggleTermCloseAll' --remote-wait"

        local urls = {}
        urls["*stackoverflow.com"] = "markdown"
        urls["*codechef.com"] = "python"
        local group = vim.api.nvim_create_augroup(
                          "nvim_ghost_user_autocommands", {clear = false})
        for url, filetype in pairs(urls) do
            vim.api.nvim_create_autocmd("User", {
                group = group,
                pattern = url,
                command = "setfiletype " .. filetype
            })
        end

        if vim.g.neovide then vim.g.neovide_fullscreen = true end

        local dap = require('dap')
        dap.adapters.cppdbg = {
            id = 'cppdbg',
            type = 'executable',
            command = '/home/matthew/extension/debugAdapters/bin/OpenDebugAD7'
        }
        dap.configurations.cpp = {
            {
                name = "Launch file",
                type = "cppdbg",
                request = "launch",
                program = function()
                    return vim.fn.input('Path to executable: ',
                                        vim.fn.getcwd() .. '/', 'file')
                end,
                cwd = '${workspaceFolder}',
                stopAtEntry = true
            }, {
                name = 'Attach to gdbserver :1234',
                type = 'cppdbg',
                request = 'launch',
                MIMode = 'gdb',
                miDebuggerServerAddress = 'localhost:1234',
                miDebuggerPath = '/usr/bin/gdb',
                cwd = '${workspaceFolder}',
                program = function()
                    return vim.fn.input('Path to executable: ',
                                        vim.fn.getcwd() .. '/', 'file')
                end
            }
        }

        vim.api.nvim_set_hl(0, "DapUIVariable", {fg = "#FFFFFF"})
    end,

    mappings = {
        n = {
            ["<leader>tp"] = toggle_term("python3"),
            ["<leader>tsp"] = toggle_term_send_n("python3"),
            ["<leader>tr"] = toggle_term("R"),
            ["<leader>tsr"] = toggle_term_send_n("R"),
            ["<C-\\>"] = {"<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal"},
            ["<leader>e"] = {"<Cmd>Neotree focus<cr>", desc = "Focus Explorer"},
            ["<leader>o"] = {
                "<Cmd>Neotree toggle<cr>",
                desc = "Toggle Explorer"
            },
            ["<leader>a"] = {"<Plug>(EasyAlign)", desc = "Align"},
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
            ["<C-\\>"] = {
                "<Esc><Cmd>ToggleTerm float<cr>",
                desc = "Toggle Terminal"
            },
            ["<leader>a"] = {"<Plug>(EasyAlign)", desc = "Align"}
        },
        t = {
            ["<C-\\>"] = {"<Cmd>ToggleTerm float<cr>", desc = "Toggle Terminal"},
            ["<M-w>"] = {
                "<C-\\><C-N>",
                desc = "Terminal normal mode",
                noremap = true
            },
            ["<C-v>"] = {
                "<C-\\><C-N>\"+pa",
                noremap = true,
                desc = "Paste from system clipboard"
            }
        },
        i = {
            ["<C-v>"] = {
                "<Esc>\"+pa",
                noremap = true,
                desc = "Paste from system clipboard"
            },
            ["<C-\\>"] = {
                "<Esc><Cmd>ToggleTerm float<cr>",
                desc = "Toggle Terminal"
            }
        }
    },
    lsp = {
        formatting = {format_on_save = false},
        config = {
            ["rust_analyzer"] = {
                settings = {
                    ["rust-analyzer"] = {
                        cargo = {features = "all"},
                        check = {features = "all"}
                    }
                }
            },
            ["lua_ls"] = {
                settings = {
                    Lua = {
                        runtime = {version = "LuaJIT"},
                        diagnostics = {globals = {"vim", "require"}},
                        workspace = {
                            library = vim.api.nvim_get_runtime_file("", true)
                        },
                        telemetry = {enable = false}
                    }
                }
            },
            ["clangd"] = function()
                local config = require("lspconfig.util");
                local root = config.root_pattern("compile_commands.json")
                local root_dir = root(vim.api.nvim_call_function("getcwd", {}))
                if root_dir == nil then root_dir = "" end
                return {
                    cmd = {
                        "clangd", "--header-insertion=never",
                        "--compile-commands-dir=" .. root_dir,
                        "--query-driver=**"
                    },
                    filetypes = {"cpp", "c"},
                    root_dir = root
                }
            end
        }
    },

    plugins = {
        {"tpope/vim-surround", lazy = false},
        {"mhinz/vim-crates", lazy = false}, {"tpope/vim-repeat", lazy = false},
        {"tpope/vim-characterize", lazy = false},
        {"farmergreg/vim-lastplace", lazy = false},
        {"junegunn/vim-easy-align", lazy = false},
        {"dccsillag/magma-nvim", lazy = false},
        -- { "subnut/nvim-ghost.nvim",   lazy = false },
        -- { "github/copilot.vim",       lazy = false },
        -- { "zbirenbaum/copilot.lua",       lazy = false }, -- TODO: install copilot.lua
        -- { "zbirenbaum/copilot-cmp",       lazy = false },
        {"junegunn/fzf", lazy = false}, {"junegunn/fzf.vim", lazy = false},
        {"chrisbra/unicode.vim", lazy = false},
        {"bazelbuild/vim-ft-bzl", lazy = false},
        -- { "google/vim-maktaba",       lazy = false }, -- dependency of vim-bazel
        -- { "bazelbuild/vim-bazel",     lazy = false }, -- currently broken?
        {"p00f/clangd_extensions.nvim"}, -- install lsp plugin
        {
            "williamboman/mason-lspconfig.nvim",
            opts = {
                ensure_installed = {"clangd"} -- automatically install lsp
            }
        }, {"max397574/cmp-greek", lazy = false},
        {"hrsh7th/cmp-calc", lazy = false}, {"hrsh7th/cmp-emoji", lazy = false},
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
                end, {"i", "s"})
                opts.mapping["<S-Tab>"] =
                    cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, {"i", "s"})
                -- cmp.register_source("calc", require("cmp_calc").new())
                opts.sources = cmp.config.sources({
                    {name = "nvim_lsp", priority = 1000},
                    {name = "luasnip", priority = 750},
                    {name = "buffer", priority = 500},
                    {name = "path", priority = 250}, {name = "greek"},
                    {name = "calc"}, {name = "emoji"}
                })
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
                opts.filesystem.filtered_items.always_show = {".gitignore"}
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
                    opts.pickers = {buffers = {}}
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
                    opts.register = {n = {}, v = {}}
                end
                opts.register.n["<leader>ts"] = {name = "Send line to terminal"}
                opts.register.n["<leader>t"] = {name = "Send lines to terminal"}
                return opts
            end
        }
    }
}
