-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

-- ============================================================================
-- Clipboard: predictable yank/paste (macOS + Linux)
-- ============================================================================
-- With clipboard=unnamedplus, every delete (d/x/c) overwrites the default
-- paste register. Remap p/P to the yank register ("0) which is only
-- populated by explicit y/y and never touched by deletes.
--
-- How Cmd/Ctrl+C/V interact:
--   y/y         → copies to both "0 and system clipboard
--   Cmd/Ctrl+C  → copies to system clipboard only (not to vim registers)
--   Cmd/Ctrl+V  → pastes from system clipboard (uses "+ register)
--   p/P          → pastes from "0 (yank register, never deleted text)
--   "+p          → explicitly paste from system clipboard (Cmd/Ctrl+V text)
--   ""p          → paste last deleted text
--
-- On macOS "+ and "* are identical (system pasteboard).
-- On Linux "+ is Ctrl+C/V clipboard, "* is middle-click selection.
vim.keymap.set({ 'n', 'v' }, 'p', '"0p', { desc = 'Paste last yanked text' })
vim.keymap.set({ 'n', 'v' }, 'P', '"0P', { desc = 'Paste last yanked above' })

return {

  ---- ============================================================
  ---- SMART-SPLITS.NVIM
  ---- ============================================================
  {
    'mrjones2014/smart-splits.nvim',

    config = function()
      require('smart-splits').setup {
        -- multiplexer_support = true,

        -- at_edge = 'pass_through',
        -- at_edge = 'wrap',

        -- Use default keybindings (recommended)
        -- default_mappings = true,
      }

      -- recommended mappings
      -- resizing splits
      -- these keymaps will also accept a range,
      -- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
      vim.keymap.set('n', '<M-h>', require('smart-splits').resize_left)
      vim.keymap.set('n', '<M-j>', require('smart-splits').resize_down)
      vim.keymap.set('n', '<M-k>', require('smart-splits').resize_up)
      vim.keymap.set('n', '<M-l>', require('smart-splits').resize_right)
      -- moving between splits
      vim.keymap.set('n', '<C-h>', require('smart-splits').move_cursor_left)
      vim.keymap.set('n', '<C-j>', require('smart-splits').move_cursor_down)
      vim.keymap.set('n', '<C-k>', require('smart-splits').move_cursor_up)
      vim.keymap.set('n', '<C-l>', require('smart-splits').move_cursor_right)
      vim.keymap.set('n', '<C-\\>', require('smart-splits').move_cursor_previous)
      -- swapping buffers between windows
      vim.keymap.set('n', '<leader><leader>h', require('smart-splits').swap_buf_left)
      vim.keymap.set('n', '<leader><leader>j', require('smart-splits').swap_buf_down)
      vim.keymap.set('n', '<leader><leader>k', require('smart-splits').swap_buf_up)
      vim.keymap.set('n', '<leader><leader>l', require('smart-splits').swap_buf_right)
    end,
  },
  -- ============================================================
  -- OIL.NVIM (File Explorer)
  -- ============================================================
  {
    'stevearc/oil.nvim',
    lazy = false,

    config = function()
      require('oil').setup {
        default_file_explorer = true,
        columns = {
          'icon',
          -- "permissions",
          -- "size",
          -- "mtime",
        },
        keymaps = {
          ['g.'] = 'actions.toggle_hidden',
          ['<CR>'] = 'actions.select',
          ['<Esc>'] = 'actions.close',
          ['q'] = 'actions.close',
          ['h'] = 'actions.parent',
          ['-'] = 'actions.parent',
          ['_'] = 'actions.open_cwd',
          ['~'] = 'actions.cd',
        },
      }

      -- Keybindings for oil
      vim.keymap.set('n', '-', '<Cmd>Oil<CR>', { desc = 'Open parent directory' })
      vim.keymap.set('n', '<leader>-', '<Cmd>Oil --float<CR>', { desc = 'Open parent directory (float)' })
    end,
  },

  {
    'huantrinh1802/m_taskwarrior_d.nvim',
    -- 'agustinottobre/m_taskwarrior_d.nvim',
    version = '*',
    dependencies = { 'MunifTanjim/nui.nvim' },
    config = function()
      require('m_taskwarrior_d').setup()
      -- Wait a bit to ensure commands are registered, then set keymaps
      vim.defer_fn(function()
        -- Set keymaps after setup runs
        vim.keymap.set('n', '<leader>te', ':TWEditTask<CR>', { desc = 'TaskWarrior Edit', silent = true })
        vim.keymap.set('n', '<leader>tv', ':TWView<CR>', { desc = 'TaskWarrior View', silent = true })
        vim.keymap.set('n', '<leader>tq', ':TWQueryTasks<CR>', { desc = 'TWQueryTasks', silent = true })
        vim.keymap.set('n', '<leader>tu', ':TWUpdateCurrent<CR>', { desc = 'TaskWarrior Update', silent = true })
        vim.keymap.set('n', '<leader>tc', ':TWSyncCurrent<CR>', { desc = 'TaskWarrior Sync Current', silent = true })
        vim.keymap.set('n', '<leader>ts', ':TWSyncTasks<CR>', { desc = 'TaskWarrior Sync Tasks', silent = true })
        vim.keymap.set('v', '<leader>ts', ':TWSyncBulk<CR>', { desc = 'TaskWarrior Sync Tasks', silent = true })
        vim.keymap.set('n', '<leader>tr', ':TWRun<CR>', { desc = 'TaskWarrior Run', silent = true })
        vim.keymap.set('v', '<leader>tr', ':TWRunBulk<CR>', { desc = 'TaskWarrior Bulk Run', silent = true })
        vim.keymap.set('n', '<C-space>', ':TWToggle<CR>', { desc = 'TaskWarrior Toggle', silent = true })
      end, 100)

      -- Setup debounced auto-sync for markdown files
      local group = vim.api.nvim_create_augroup('TWTask', { clear = true })
      local timer = vim.uv.new_timer()

      -- vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
      vim.api.nvim_create_autocmd({ 'BufWritePost' }, {
        group = group,
        pattern = { '*.md', '*.markdown' },
        callback = function(args)
          -- 1. Performance check: Skip files larger than 100KB
          local max_size = 100 * 1024
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(args.buf))
          if not ok or not stats or stats.size > max_size then return end
          -- 2. Debounce: Wait 2 seconds after the last event before syncing
          timer:stop()
          timer:start(
            1000,
            0,
            vim.schedule_wrap(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                vim.cmd 'TWSyncTasks'
                -- Optional: notify user it synced
                vim.notify('TaskWarrior synced', vim.log.levels.INFO)
              end
            end)
          )
        end,
      })
    end,
    opts = {
      -- status_map = { [" "] = "pending", [">"] = "active", ["x"] = "completed", ["~"] = "deleted" },
      display_due_or_scheduled = false, -- Display due or scheduled tasks in the task list, for performance reasons
    },
  },

  {
    'jakewvincent/mkdnflow.nvim',
    ft = { 'markdown', 'rmd' }, -- Add custom filetypes here if configured
    config = function()
      require('mkdnflow').setup {
        modules = {
          bib = true,
          buffers = true,
          conceal = true,
          cursor = true,
          folds = true,
          foldtext = true,
          links = true,
          lists = true,
          maps = true,
          paths = true,
          tables = true,
          templates = true,
          to_do = true,
          yaml = false,
          cmp = false,
        },
        foldtext = {
          object_count = true,
          object_count_icon_set = 'emoji',
          object_count_opts = function() return require('mkdnflow').foldtext.default_count_opts() end,
          line_count = true,
          line_percentage = true,
          word_count = false,
          title_transformer = function() return require('mkdnflow').foldtext.default_title_transformer end,
          fill_chars = {
            left_edge = '⢾⣿⣿',
            right_edge = '⣿⣿⡷',
            item_separator = ' · ',
            section_separator = ' ⣹⣿⣏ ',
            left_inside = ' ⣹',
            right_inside = '⣏ ',
            middle = '⣿',
          },
        },
        links = {
          transform_on_create = function(text)
            text = text:gsub(' ', '-')
            text = text:lower()
            return text
          end,
        },
        new_file_template = {
          enabled = true,
          placeholders = {
            title = 'link_title',
          },
          template = '# {{ title}}',
        },
        mappings = {
          MkdnToggleToDo = false, -- Disable the toggle checkbox to work with huantrinh1802/m_taskwarrior_d.nvim
        },
      }
    end,
  },

  {
    'mbbill/undotree',
    config = function()
      -- Undotree
      vim.keymap.set('n', '<leader>ut', '<Cmd>UndotreeToggle<CR>', { desc = 'Toggle undotree' })
    end,
  },
  {
    'junegunn/goyo.vim',
    cmd = 'Goyo',
    -- Set the keybinding outside the config to load on startup
    vim.keymap.set('n', '<leader>go', '<Cmd>Goyo<CR>', { desc = 'Toggle Goyo' }),
  },
  {
    'folke/twilight.nvim',
    cmd = 'Twilight',
  },
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {
      -- NOTE: The log_level is in `opts.opts`
      opts = {
        log_level = 'DEBUG', -- or "TRACE"
      },
    },
    --     display = {
    --       diff = {
    --         enabled = true,
    --         close_chat_at = 240, -- Close an open chat buffer if the total columns of your display are less than...
    --         layout = 'vertical', -- vertical|horizontal split for default provider
    --         opts = { 'internal', 'filler', 'closeoff', 'algorithm:patience', 'followwrap', 'linematch:120' },
    --         provider = 'default', -- default|mini_diff
    --       },
    --     },
    config = function()
      require('codecompanion').setup {
        adapters = {
          http = {
            ollama = function()
              return require('codecompanion.adapters').extend('ollama', {
                env = {
                  url = 'http://192.168.127.7:11434',
                  -- api_key = 'OLLAMA_API_KEY',
                },
                headers = {
                  ['Content-Type'] = 'application/json',
                  -- ['Authorization'] = 'Bearer ${api_key}',
                },
                parameters = {
                  sync = true,
                },
                schema = {
                  model = {
                    default = 'gpt-oss:20b-128k',
                  },
                },
              })
            end,
          },
          duckduckgo = function()
            return require('codecompanion.adapters').extend('http', {
              url = 'https://api.duckduckgo.com/',
              headers = {}, -- no API key needed
              parameters = {
                format = 'json', -- return JSON
                no_html = 1, -- plain text answer
                skip_disambig = 1, -- skip disambiguation pages
              },
            })
          end,
          opts = {
            allow_insecure = true,
          },
        },
        interactions = {
          chat = {
            adapter = 'ollama',
          },
          inline = {
            adapter = 'ollama',
          },
          cmd = {
            adapter = 'ollama',
          },
        },
      }
    end,
  },
}
