local manager = require 'nvim-tree-preview.manager'

local M = {}

---@param config? PreviewConfig
function M.setup(config)
  require('nvim-tree-preview.config').setup(config or {})
end

M.node = manager.node
M.node_under_cursor = manager.node_under_cursor
M.close = manager.close
M.is_watching = manager.is_watching
M.watch = manager.watch
M.unwatch = manager.unwatch

return M
