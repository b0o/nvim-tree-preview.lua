local api = require 'nvim-tree.api'

local Preview = require 'nvim-tree-preview.preview'

---@class PreviewModule
---@field instance? Preview
---@field watch_augroup? number
---@field watch_tree_buf? number
local M = {
  instance = nil,
  watch_augroup = nil,
  tree_buf = nil,
}

---@param config? PreviewConfig
function M.setup(config)
  require('nvim-tree-preview.config').setup(config or {})
end

---@param node NvimTreeNode
---@param opts? {toggle_focus?: boolean}
function M.node(node, opts)
  opts = vim.tbl_extend('force', { toggle_focus = false }, opts or {})
  if not M.instance then
    M.instance = Preview.create()
  end
  if not node.type then
    M.instance:close()
    return
  end
  if M.instance:is_open() then
    if M.instance.tree_node.absolute_path == node.absolute_path then
      if opts.toggle_focus then
        M.instance:toggle_focus()
      end
      return
    end
  end
  M.instance:open(node)
end

---@param opts? {toggle_focus?: boolean}
function M.node_under_cursor(opts)
  opts = vim.tbl_extend('force', { toggle_focus = true }, opts or {})
  local ok, node = pcall(api.tree.get_node_under_cursor)
  if not ok then
    if M.instance and M.instance:is_open() then
      M.instance:close()
    end
    return
  end
  M.node(node, opts)
end

function M.close()
  if M.instance then
    M.instance:close()
  end
end

function M.is_watching()
  return M.watch_augroup ~= nil
end

function M.watch()
  if M.watch_augroup then
    M.unwatch()
    return
  end
  if vim.bo.ft ~= 'NvimTree' then
    vim.notify('Cannot watch preview: current buffer is not NvimTree', vim.log.levels.ERROR)
    return
  end
  M.watch_augroup = vim.api.nvim_create_augroup('nvim_tree_preview_watch', { clear = true })
  M.watch_tree_buf = vim.api.nvim_get_current_buf()
  if not M.instance or not M.instance:is_open() then
    M.node_under_cursor()
  end
  M.instance:set_watched(true)
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    group = M.watch_augroup,
    buffer = 0,
    callback = function()
      local ok, node = pcall(api.tree.get_node_under_cursor)
      if not ok or not node then
        M.close()
      else
        vim.schedule(function()
          M.node(node, { toggle_focus = false })
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
    group = M.watch_augroup,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if buf == M.watch_tree_buf then
        local ok, node = pcall(api.tree.get_node_under_cursor)
        if not ok or not node then
          M.close()
        end
      elseif M.instance and buf == M.instance.preview_buf then
        return
      else
        M.unwatch()
      end
    end,
  })
end

function M.unwatch()
  if M.watch_augroup then
    vim.api.nvim_del_augroup_by_id(M.watch_augroup)
    M.watch_augroup = nil
  end
  if M.instance then
    M.instance:close()
    M.instance:set_watched(false)
  end
end

return M
