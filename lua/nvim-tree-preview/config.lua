---@alias PreviewKeymapOpenDirection 'edit'|'tab'|'vertical'|'horizontal'
---@alias PreviewKeymapActionClose {action: 'close', focus_tree?: boolean, unwatch?: boolean}
---@alias PreviewKeymapActionToggleFocus {action: 'toggle_focus'}
---@alias PreviewKeymapAction PreviewKeymapActionClose|PreviewKeymapActionToggleFocus
---@alias PreviewKeymap string|function|PreviewKeymapAction|{open: PreviewKeymapOpenDirection}
---@alias PreviewKeymapSpec {[1]: string, [2]: PreviewKeymap}

---@class PreviewConfig
---@field keymaps? Map<string, PreviewKeymap>
---@field min_width? number
---@field min_height? number
---@field max_width? number
---@field max_height? number
---@field wrap? boolean
---@field border? any
---@field zindex? number
---@field show_title? boolean
---@field title_pos? 'top-left'|'top-center'|'top-right'|'bottom-left'|'bottom-center'|'bottom-right'
---@field title_format? string

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
  },
}

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
    ({
      'top-left',
      'top-center',
      'top-right',
      'bottom-left',
      'bottom-center',
      'bottom-right',
    })[M.config.title_pos],
    'title_pos must be one of top-left, top-center, top-right, bottom-left, bottom-center, bottom-right'
  )
end

return setmetatable({}, {
  __index = function(_, k)
    if k == 'setup' then
      return setup
    end
    return M.config[k]
  end,
})
