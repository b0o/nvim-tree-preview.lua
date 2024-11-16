local Path = require 'plenary.path'
local api = require 'nvim-tree.api'

local util = require 'nvim-tree-preview.util'
local config = require 'nvim-tree-preview.config'

---@class Preview
local Preview = {}

---@param manager PreviewManager
Preview.create = function(manager)
  return setmetatable({
    manager = manager,
    augroup = nil,
    preview_win = nil,
    preview_buf = nil,
    tree_win = nil,
    tree_buf = nil,
    tree_node = nil,
  }, { __index = Preview })
end

function Preview:is_open()
  return self.preview_win ~= nil and vim.api.nvim_win_is_valid(self.preview_win)
end

function Preview:is_focused()
  return self:is_open() and vim.api.nvim_get_current_win() == self.preview_win
end

---@param opts? {focus_tree?: boolean, unwatch?: boolean}
function Preview:close(opts)
  opts = vim.tbl_extend('force', { focus_tree = true, unwatch = false }, opts or {})
  if self.augroup ~= nil then
    vim.api.nvim_del_augroup_by_id(self.augroup)
  end
  if opts.unwatch then
    self.manager.unwatch { close = false }
  end
  if self.preview_win ~= nil then
    if vim.api.nvim_win_is_valid(self.preview_win) then
      vim.api.nvim_win_close(self.preview_win, true)
    end
    if opts.focus_tree and self.tree_win and self:is_focused() then
      vim.api.nvim_set_current_win(self.tree_win)
    end
  end
  self:unload_buf()
  self.augroup = nil
  self.preview_win = nil
  self.preview_buf = nil
  self.tree_win = nil
  self.tree_buf = nil
  self.tree_node = nil
end

function Preview:setup_autocmds()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = self.augroup,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if not (buf == self.tree_buf or buf == self.preview_buf) then
        self:close { focus_tree = false }
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = self.augroup,
    pattern = tostring(self.preview_win),
    once = true,
    callback = function()
      self:close { focus_tree = false, unwatch = true }
    end,
  })
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = self.augroup,
    buffer = self.tree_buf,
    callback = function()
      if self.manager.is_watching() then
        -- Do not close the preview window if watching, so that
        -- future CursorMoved events can re-use the same window.
        return
      end
      local ok, node = pcall(api.tree.get_node_under_cursor)
      local self_node = self.tree_node
      if not ok or not node or not self_node or node.absolute_path ~= self_node.absolute_path then
        self:close()
      end
    end,
  })
end

function Preview:setup_keymaps()
  ---@param key PreviewKeymapAction
  ---@param opts? any
  ---@return function
  local action = function(key, opts)
    if not vim.tbl_contains({ 'close', 'toggle_focus' }, key) then
      vim.notify('nvim-tree preview: Invalid keymap action ' .. key, vim.log.levels.ERROR)
      return function() end
    end
    return function()
      vim.schedule(function()
        self[key](self, opts)
      end)
    end
  end

  ---@param mode PreviewKeymapOpenDirection
  ---@return function
  local open = function(mode)
    if not vim.tbl_contains({ 'edit', 'tab', 'vertical', 'horizontal' }, mode) then
      vim.notify('nvim-tree preview: Invalid keymap open mode ' .. mode, vim.log.levels.ERROR)
      return function() end
    end
    return function()
      self.manager.unwatch { close = false }
      self:close { focus_tree = false }
      vim.schedule(function()
        api.node.open[mode]()
      end)
    end
  end

  local map_opts = { buffer = self.preview_buf, noremap = true, silent = true }
  for key, spec in pairs(config.keymaps) do
    if type(spec) == 'string' then
      vim.keymap.set('n', key, spec, map_opts)
    elseif util.is_callable(spec) then
      ---@type PreviewKeymapFnParams
      local params = {
        node = self.tree_node,
      }
      vim.keymap.set('n', key, function()
        spec(params)
      end, map_opts)
    elseif type(spec) == 'table' then
      if spec.action then
        vim.keymap.set('n', key, action(spec.action, spec), map_opts)
      elseif spec.open then
        local open_mode = spec.open
        ---@cast open_mode PreviewKeymapOpenDirection
        vim.keymap.set('n', key, open(open_mode), map_opts)
      else
        vim.notify('nvim-tree preview: Invalid keymap spec for ' .. key, vim.log.levels.ERROR)
      end
    elseif spec == false then
      -- pass
    else
      vim.notify('nvim-tree preview: Invalid keymap spec for ' .. key, vim.log.levels.ERROR)
    end
  end
end

---@param node NvimTreeNode
---@return string[]
local function read_directory(node)
  local content = vim.fn.readdir(node.absolute_path)
  if not content or #content == 0 then
    return { 'Error reading directory' }
  end
  local files = vim.tbl_map(function(name)
    return {
      name = name,
      is_dir = vim.fn.isdirectory(node.absolute_path .. '/' .. name) == 1,
    }
  end, content)
  table.sort(files, function(a, b)
    if a.is_dir ~= b.is_dir then
      return a.is_dir
    end
    return a.name < b.name
  end)
  content = { '  ' .. node.name .. '/' }
  for i, file in ipairs(files) do
    local prefix = i == #files and ' └ ' or ' │ '
    if file.is_dir then
      table.insert(content, prefix .. file.name .. '/')
    else
      table.insert(content, prefix .. file.name)
    end
  end
  return content
end

---Execute a function without triggering any autocommands
---@generic TArgs
---@generic TReturn
---@param cb fun(...: TArgs): TReturn
---@param ... TArgs the arguments to pass to the function
---@return TReturn res the result of the
local noautocmd = function(cb, ...)
  local eventignore = vim.opt.eventignore
  ---@diagnostic disable-next-line: undefined-field
  vim.opt.eventignore:append 'BufEnter,BufWinEnter,BufAdd,BufNew,BufCreate,BufReadPost'
  local res = cb(...)
  vim.opt.eventignore = eventignore
  return res
end

-- Adapted from telescope.nvim:
-- https://github.com/nvim-telescope/telescope.nvim/blob/35f94f0ef32d70e3664a703cefbe71bd1456d899/lua/telescope/previewers/buffer_previewer.lua#L199
function Preview:load_file_content(path)
  local buf = self.preview_buf
  Path:new(path):_read_async(vim.schedule_wrap(function(data)
    if not buf or self.preview_buf ~= buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local processed_data = vim.split(data, '[\r]?\n')
    if processed_data then
      vim.bo[buf].modifiable = true
      local ok = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, processed_data)
      vim.bo[buf].modifiable = false
      if not ok then
        return
      end
      local ft = vim.filetype.match { buf = buf, filename = self.tree_node.absolute_path }
      if ft and vim.bo[buf].filetype ~= ft then
        vim.bo[buf].filetype = ft
      end
    end
  end))
end

---Load the content for the target node into the preview buffer
function Preview:load_buf_content()
  if not self.tree_node or not self.preview_buf then
    return
  end
  if self.tree_node.type == 'file' then
    self:load_file_content(self.tree_node.absolute_path)
    return
  end

  ---@type string[]?
  local content
  if self.tree_node.type == 'directory' then
    content = read_directory(self.tree_node)
  else
    content = { self.tree_node.name .. ' → ' .. self.tree_node.link_to }
  end
  local buf = self.preview_buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
end

---Update the title of the preview window
function Preview:update_title()
  if not self.tree_node or not config.show_title then
    return
  end
  local name = self.tree_node.name .. (self.tree_node.type == 'directory' and '/' or '')
  local title = string.format(config.title_format or ' %s ', name)
  local pos_y, pos_x = unpack(vim.split(config.title_pos, '-'))
  ---@type vim.api.keyset.win_config
  local opts = {}
  if pos_y == 'top' then
    opts.title_pos = pos_x
    opts.title = title
  else
    opts.footer_pos = pos_x
    opts.footer = title
  end
  vim.api.nvim_win_set_config(self.preview_win, opts)
end

---Get the desired size of the preview window
---@return {width: number, height: number}
function Preview:get_size()
  local width = vim.api.nvim_get_option_value('columns', {})
  local height = vim.api.nvim_get_option_value('lines', {})
  return {
    width = math.min(config.max_width, math.max(config.min_width, math.ceil(width / 2))),
    height = math.min(config.max_height, math.max(config.min_height, math.ceil(height / 2))),
  }
end

---Get the window handle for the preview window
---@return number window The window handle
function Preview:get_win()
  local view_side = require('nvim-tree').config.view.side
  local size = self:get_size()
  local opts = {
    width = size.width,
    height = size.height,
    row = math.max(0, vim.fn.screenrow() - 1),
    -- if view.side is 'right', then the preview window will be on the left of nvim-tree
    col = (view_side == 'left' and vim.fn.winwidth(0) + 1 or -size.width - 3),
    relative = 'win',
  }
  if self.preview_win and vim.api.nvim_win_is_valid(self.preview_win) then
    vim.api.nvim_win_set_config(self.preview_win, opts)
    return self.preview_win
  end
  opts = vim.tbl_extend('force', opts, {
    noautocmd = true,
    focusable = false,
    border = config.border,
    zindex = config.zindex,
  })
  local win = noautocmd(vim.api.nvim_open_win, self.preview_buf, false, opts)
  vim.wo[win].wrap = config.wrap
  vim.wo[win].scrolloff = 0
  self.preview_win = win
  return win
end

function Preview:unload_buf()
  if self.preview_buf and vim.api.nvim_buf_is_valid(self.preview_buf) then
    vim.api.nvim_buf_delete(self.preview_buf, { force = true })
  end
  self.preview_buf = nil
end

---Reset cursor and scroll position in preview window
function Preview:reset_cursor()
  if not self.preview_win or not vim.api.nvim_win_is_valid(self.preview_win) then
    return
  end

  vim.api.nvim_win_set_cursor(self.preview_win, { 1, 0 })
  vim.api.nvim_win_call(self.preview_win, function()
    vim.fn.winrestview { topline = 1, leftcol = 0 }
  end)
end

---Creates or updates a preview buffer for the given node
---@param node NvimTreeNode
---@return number buffer The buffer number
function Preview:setup_preview_buffer(node)
  local needs_new_buffer = not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf)

  if needs_new_buffer then
    self.preview_buf = vim.api.nvim_create_buf(false, true)
    -- Set buffer options that only need to be set once
    vim.bo[self.preview_buf].bufhidden = 'delete'
    vim.bo[self.preview_buf].buftype = 'nofile'
    vim.bo[self.preview_buf].swapfile = false
    vim.bo[self.preview_buf].buflisted = false
    vim.bo[self.preview_buf].modifiable = false
  end

  -- Always update buffer name to match current node
  vim.api.nvim_buf_set_name(self.preview_buf, 'nvim-tree-preview://' .. node.absolute_path)

  return self.preview_buf
end

---Initialize the preview window and its settings
---@param win number Window handle
---@param node NvimTreeNode
function Preview:init_preview_window(win, node)
  vim.wo[win].number = node.type == 'file'
  self.augroup = vim.api.nvim_create_augroup('nvim_tree_preview', { clear = true })
  vim.schedule(function()
    self:setup_autocmds()
    self:setup_keymaps()
    self:update_title()
    self:load_buf_content()
  end)
end

---Open the preview window for the given node
---@param node NvimTreeNode
function Preview:open(node)
  self.tree_win = vim.api.nvim_get_current_win()
  self.tree_buf = vim.api.nvim_get_current_buf()

  local is_different_node = not self.tree_node or self.tree_node.absolute_path ~= node.absolute_path
  local is_first_open = not self:is_open()

  self.tree_node = node
  local preview_buf = self:setup_preview_buffer(node)
  local win = self:get_win()

  if is_first_open then
    self:init_preview_window(win, node)
  elseif is_different_node then
    vim.schedule(function()
      self:update_title()
      self:load_buf_content()
      self:reset_cursor()
    end)
  end

  noautocmd(vim.api.nvim_win_set_buf, win, preview_buf)
end

---Returns the height of the preview window's content.
---@return number
function Preview:win_buf_height()
  local buf = self.preview_buf --[[ @as number ]]
  local win = self.preview_win --[[ @as number ]]
  if not vim.wo[win].wrap then
    return vim.api.nvim_buf_line_count(buf)
  end
  local width = vim.api.nvim_win_get_width(win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local height = 0
  for _, l in ipairs(lines) do
    height = height + math.max(1, (math.ceil(vim.fn.strwidth(l) / width)))
  end
  return height
end

---Scrolls the preview window by the given number of lines.
---Adapted from noice.nvim:
---https://github.com/folke/noice.nvim/blob/df448c649ef6bc5a6/lua/noice/util/nui.lua#L238
---@param delta number
function Preview:scroll(delta)
  if not self:is_open() then
    return false
  end
  local win = self.preview_win --[[ @as number ]]
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local height = vim.api.nvim_win_get_height(win)
  local top = view.topline
  top = top + delta
  top = math.max(top, 1)
  top = math.min(top, self:win_buf_height() - height + 1)
  vim.defer_fn(function()
    vim.api.nvim_win_call(win, function()
      vim.fn.winrestview { topline = top, lnum = top }
    end)
  end, 0)
  return true
end

function Preview:toggle_focus()
  if not self:is_open() then
    return
  end
  local win = vim.api.nvim_get_current_win()
  if win == self.preview_win then
    vim.schedule(function()
      if self.tree_win and vim.api.nvim_win_is_valid(self.tree_win) then
        vim.api.nvim_set_current_win(self.tree_win)
      end
    end)
  else
    vim.schedule(function()
      if self.preview_win and vim.api.nvim_win_is_valid(self.preview_win) then
        vim.api.nvim_set_current_win(self.preview_win)
      end
    end)
  end
end

return Preview
