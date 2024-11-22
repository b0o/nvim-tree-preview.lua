---@type {config: PreviewConfig}
local M = {
  config = {
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
    wrap = false,
    border = 'rounded',
    zindex = 100,
    show_title = true,
    title_pos = 'top-center',
    title_format = ' %s ',
    on_open = nil,
    on_close = nil,
  },
}

---@param config? PreviewConfigSetup
local function setup(config)
  config = config or {}
  M.config = vim.tbl_deep_extend('force', M.config, config)
  assert(M.config.min_width <= M.config.max_width, 'min_width must be less than or equal to max_width')
  assert(M.config.min_height <= M.config.max_height, 'min_height must be less than or equal to max_height')
  assert(M.config.min_width > 0, 'min_width must be greater than 0')
  assert(M.config.min_height > 0, 'min_height must be greater than 0')
  assert(M.config.max_width > 0, 'max_width must be greater than 0')
  assert(M.config.max_height > 0, 'max_height must be greater than 0')
  assert(M.config.zindex > 0, 'zindex must be greater than 0')
  assert(
    vim.tbl_contains(
      { 'top-left', 'top-center', 'top-right', 'bottom-left', 'bottom-center', 'bottom-right' },
      M.config.title_pos
    ),
    'title_pos must be one of top-left, top-center, top-right, bottom-left, bottom-center, bottom-right'
  )
  assert(type(M.config.title_format) == 'string', 'title_format must be a string')
  assert(type(M.config.on_open) == 'function' or M.config.on_open == nil, 'on_open must be a function or nil')
  assert(type(M.config.on_close) == 'function' or M.config.on_close == nil, 'on_close must be a function or nil')
end

return setmetatable({}, {
  __index = function(_, k)
    if k == 'setup' then
      return setup
    end
    return M.config[k]
  end,
}) --[[@as PreviewConfig]]
