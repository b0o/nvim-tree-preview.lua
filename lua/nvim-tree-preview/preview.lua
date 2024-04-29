local Path = require 'plenary.path'
local api = require 'nvim-tree.api'

local config = require 'nvim-tree-preview.config'

---@class NvimTreeNode
---@field absolute_path string
---@field executable boolean
---@field extension string
---@field filetype string
---@field link_to string
---@field name string
---@field type 'file' | 'directory' | 'link'

---@class Preview
---@field manager PreviewManager
---@field augroup number?
---@field preview_win number?
---@field preview_buf number?
---@field tree_win number?
---@field tree_buf number?
---@field tree_node NvimTreeNode?
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
  return self.preview_win ~= nil
end

function Preview:is_focused()
  return self:is_open() and vim.api.nvim_get_current_win() == self.preview_win
end

---@param opts? {focus_tree?: boolean, unwatch?: boolean}
function Preview:close(opts)
  opts = vim.tbl_extend('force', { focus_tree = true, unwatch = false }, opts or {})
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
  if self.augroup ~= nil then
    vim.api.nvim_del_augroup_by_id(self.augroup)
  end
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

local function noop()
  -- noop
end

function Preview:setup_keymaps()
  ---@param key PreviewKeymapAction
  ---@param opts? any
  ---@return function
  local action = function(key, opts)
    if not vim.tbl_contains({ 'close', 'toggle_focus' }, key) then
      vim.notify('nvim-tree preview: Invalid keymap action ' .. key, vim.log.levels.ERROR)
      return noop
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
      return noop
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
    if type(spec) == 'string' or type(spec) == 'function' then
      vim.keymap.set('n', key, spec, map_opts)
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

local noautocmd = function(cb, ...)
  local eventignore = vim.opt.eventignore
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

function Preview:get_win()
  local width = vim.api.nvim_get_option_value('columns', {})
  local height = vim.api.nvim_get_option_value('lines', {})
  local opts = {
    width = math.min(config.max_width, math.max(config.min_width, math.ceil(width / 2))),
    height = math.min(config.max_height, math.max(config.min_height, math.ceil(height / 2))),
    row = math.max(0, vim.fn.screenrow() - 1),
    col = vim.fn.winwidth(0) + 1,
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
  })
  local win = noautocmd(vim.api.nvim_open_win, self.preview_buf, false, opts)
  vim.wo[win].wrap = config.wrap
  self.preview_win = win
  return win
end

---@param node NvimTreeNode
function Preview:open(node)
  if not self.tree_node or self.tree_node.absolute_path ~= node.absolute_path then
    self.preview_buf = nil
  end
  self.tree_win = vim.api.nvim_get_current_win()
  self.tree_buf = vim.api.nvim_get_current_buf()
  self.tree_node = node

  ---@type number?
  local preview_buf = nil
  if not self.preview_buf or not vim.api.nvim_buf_is_valid(self.preview_buf) then
    preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(preview_buf, 'nvim-tree-preview://' .. node.absolute_path)
    self.preview_buf = preview_buf
  end

  local win = self:get_win()
  vim.wo[win].number = node.type == 'file'

  if preview_buf then
    self.augroup = vim.api.nvim_create_augroup('nvim_tree_preview', { clear = true })

    noautocmd(vim.api.nvim_win_set_buf, win, preview_buf)
    vim.bo[preview_buf].bufhidden = 'delete'
    vim.bo[preview_buf].buftype = 'nofile'
    vim.bo[preview_buf].swapfile = false
    vim.bo[preview_buf].buflisted = false
    vim.bo[preview_buf].modifiable = false

    vim.schedule(function()
      self:setup_autocmds()
      self:setup_keymaps()
      self:load_buf_content()
    end)
  end
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
