local manager = require 'nvim-tree-preview.manager'

local M = {}

---@param config? PreviewConfigSetup
function M.setup(config)
  ---@diagnostic disable-next-line: undefined-field
  require('nvim-tree-preview.config').setup(config or {})
end

M.node = manager.node
M.node_under_cursor = manager.node_under_cursor
M.close = manager.close
M.watch = manager.watch
M.unwatch = manager.unwatch
M.is_open = manager.is_open
M.is_focused = manager.is_focused
M.is_watching = manager.is_watching
M.scroll = manager.scroll

return M
