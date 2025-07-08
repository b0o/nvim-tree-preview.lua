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
    follow_links = true,
    win_position = {},
    image_preview = {
      enable = false,
      patterns = {
        '.*%.png$',
        '.*%.jpg$',
        '.*%.jpeg$',
        '.*%.gif$',
        '.*%.webp$',
        '.*%.avif$',
      },
    },
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
  assert(type(M.config.follow_links) == 'boolean', 'follow_links must be a boolean')
  assert(type(M.config.win_position) == 'table', 'win_position must be a table')
  assert(
    M.config.win_position.row == nil
      or (type(M.config.win_position.row) == 'number' or type(M.config.win_position.row) == 'function'),
    'win_position.row must be a number, function returning a number, or nil'
  )
  assert(
    M.config.win_position.col == nil
      or (type(M.config.win_position.col) == 'number' or type(M.config.win_position.col) == 'function'),
    'win_position.col must be a number, function returning a number, or nil'
  )
  assert(type(M.config.on_open) == 'function' or M.config.on_open == nil, 'on_open must be a function or nil')
  assert(type(M.config.on_close) == 'function' or M.config.on_close == nil, 'on_close must be a function or nil')
  assert(type(M.config.image_preview) == 'table', 'image_preview must be a table')
  assert(type(M.config.image_preview.enable) == 'boolean', 'image_preview.enable must be a boolean')
  assert(type(M.config.image_preview.patterns) == 'table', 'image_preview.patterns must be a table')
  for _, pattern in ipairs(M.config.image_preview.patterns) do
    assert(type(pattern) == 'string', 'image_preview.patterns must be a table of strings')
  end
end

return setmetatable({}, {
  __index = function(_, k)
    if k == 'setup' then
      return setup
    end
    return M.config[k]
  end,
}) --[[@as PreviewConfig]]
