# nvim-tree-preview.lua

Preview [NvimTree](https://github.com/nvim-tree/nvim-tree.lua/) files in a floating window.

https://github.com/b0o/nvim-tree-preview.lua/assets/21299126/239dd210-7c03-4637-8dce-9999da658396

## Installation

Lazy.nvim:

```lua
{
  'kyazdani42/nvim-tree.lua',
  dependencies = {
    'b0o/nvim-tree-preview.lua',
  },
},
```

NOTE: Depends on [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). You likely already have this installed, if not:

```lua
{
  'nvim-lua/plenary.nvim',
},
```


Configuration:

To use nvim-tree-preview, set up mappings to toggle it in your nvim-tree `on_attach` function (see [`:help nvim-tree.on_attach`](https://github.com/nvim-tree/nvim-tree.lua/blob/5a18b9827491aa1aea710bc9b85c6b63ed0dad14/doc/nvim-tree-lua.txt#L644)):

```lua
require('nvim-tree').setup {
  on_attach = function(bufnr)
    local api = require('nvim-tree.api')

    -- Important: When you supply an `on_attach` function, nvim-tree won't
    -- automatically set up the default keymaps. To set up the default keymaps,
    -- call the `default_on_attach` function. See `:help nvim-tree-quickstart-custom-mappings`.
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
      return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    local preview = require('nvim-tree-preview')

    vim.keymap.set('n', 'P', preview.watch, opts 'Preview (Watch)')
    vim.keymap.set('n', '<Esc>', preview.unwatch, opts 'Close Preview/Unwatch')
    vim.keymap.set('n', '<C-f>', function() return preview.scroll(4) end, opts 'Scroll Down')
    vim.keymap.set('n', '<C-b>', function() return preview.scroll(-4) end, opts 'Scroll Up')

    -- Option A: Smart tab behavior: Only preview files, expand/collapse directories (recommended)
    vim.keymap.set('n', '<Tab>', function()
      local ok, node = pcall(api.tree.get_node_under_cursor)
      if ok and node then
        if node.type == 'directory' then
          api.node.open.edit()
        else
          preview.node(node, { toggle_focus = true })
        end
      end
    end, opts 'Preview')

    -- Option B: Simple tab behavior: Always preview
    -- vim.keymap.set('n', '<Tab>', preview.node_under_cursor, opts 'Preview')
  end,
}
```

Optionally, you can call nvim-tree-preview's `setup()` function to change the default configuration:

```lua
-- Default config:
require('nvim-tree-preview').setup {
  -- Keymaps for the preview window (does not apply to the tree window).
  -- Keymaps can be a string (vimscript command), a function, or a table.
  --
  -- If a function is provided:
  --   When the keymap is invoked, the function is called.
  --   It will be passed a single argument, which is a table of the following form:
  --     {
  --       node: NvimTreeNode|NvimTreeRootNode, -- The tree node under the cursor
  --     }
  --   See the type definitions in `lua/nvim-tree-preview/types.lua` for a description
  --   of the fields in the table.
  --
  -- If a table, it must contain either an 'action' or 'open' key:
  --   Actions:
  --     { action = 'close', unwatch? = false, focus_tree? = true }
  --     { action = 'toggle_focus' }
  --     { action = 'select_node', target: 'next'|'prev' }
  --
  --   Open modes:
  --     { open = 'edit' }
  --     { open = 'tab' }
  --     { open = 'vertical' }
  --     { open = 'horizontal' }
  --
  -- To disable a default keymap, set it to false.
  -- All keymaps are set in normal mode. Other modes are not currently supported.
  keymaps = {
    ['<Esc>'] = { action = 'close', unwatch = true },
    ['<Tab>'] = { action = 'toggle_focus' },
    ['<CR>'] = { open = 'edit' },
    ['<C-t>'] = { open = 'tab' },
    ['<C-v>'] = { open = 'vertical' },
    ['<C-x>'] = { open = 'horizontal' },
    ['<C-n>'] = { action = 'select_node', target = 'next' },
    ['<C-p>'] = { action = 'select_node', target = 'prev' },
  },
  min_width = 10,
  min_height = 5,
  max_width = 85,
  max_height = 25,
  wrap = false, -- Whether to wrap lines in the preview window
  border = 'rounded', -- Border style for the preview window
  zindex = 100, -- Stacking order. Increase if the preview window is shown below other windows.
  show_title = true, -- Whether to show the file name as the title of the preview window
  title_pos = 'top-left', -- top-left|top-center|top-right|bottom-left|bottom-center|bottom-right
  title_format = ' %s ',
  on_open = nil, -- fun(win: number, buf: number) called when the preview window is opened
  on_close = nil, -- fun() called when the preview window is closed
}
```


If you're using [nvim-window-picker](https://github.com/s1n7ax/nvim-window-picker), it's recommended to ignore nvim-tree-preview windows:

```lua
require('nvim-tree').setup {
  actions = {
    open_file = {
      window_picker = {
        enable = true,
        picker = function()
          return require('window-picker').pick_window {
            filter_rules = {
              file_path_contains = { 'nvim-tree-preview://' },
            },
          }
        end,
      },
    },
  },
}
```

## API

nvim-tree-preview exposes a few functions for programmatically interacting with the preview window.

```lua
local preview = require 'nvim-tree-preview'

---Open a preview window for the given nvim-tree node.
---If toggle_focus is true and a preview window is already open for the node,
---the preview window will be focused.
---@param node NvimTreeNode
---@param opts? {toggle_focus?: boolean (default: false)}
preview.node(node, opts)

---Preview the node under the cursor in the nvim-tree window.
---If toggle_focus is true and a preview window is already open for the node,
---the preview window will be focused.
---@param opts? {toggle_focus?: boolean (default: true)}
preview.node_under_cursor(opts)

---Close the preview window.
preview.close()

---Open the preview window for the node under the cursor, and
---watch for cursor movement in the nvim-tree window. If the cursor is moved
---to a different node, the preview window display the content of that node.
preview.watch()

---Stop watching for cursor movement in the nvim-tree window.
---If close is true, the preview window will be closed if it is open.
---@param opts? {close?: boolean (default: true)}
preview.unwatch(opts)

---Returns true if a preview window is open.
preview.is_open()

---Returns true if the preview window is focused.
preview.is_focused()

---Returns true if the preview window is currently being watched.
preview.is_watching()

---Scrolls the preview window by the given number of lines. Use a negative number to scroll up.
---@param amount number
---@return boolean success true if the preview window is open and the scroll was successful.
preview.scroll(amount)
```

## Alternatives

- [JMarkin/nvim-tree.lua-float-preview](https://github.com/JMarkin/nvim-tree.lua-float-preview/)

## License

Copyright (C) 2024 Maddison Hellstrom

MIT License
