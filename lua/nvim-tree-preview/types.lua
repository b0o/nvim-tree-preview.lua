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

---@alias PreviewKeymapOpenDirection 'edit'|'tab'|'vertical'|'horizontal'
---@alias PreviewKeymapActionClose {action: 'close', focus_tree?: boolean, unwatch?: boolean}
---@alias PreviewKeymapActionToggleFocus {action: 'toggle_focus'}
---@alias PreviewKeymapAction PreviewKeymapActionClose|PreviewKeymapActionToggleFocus
---@alias PreviewKeymap string|function|PreviewKeymapAction|{open: PreviewKeymapOpenDirection}
---@alias PreviewKeymapSpec {[1]: string, [2]: PreviewKeymap}

---@class PreviewConfig
---@field keymaps Map<string, PreviewKeymap>
---@field min_width number
---@field min_height number
---@field max_width number
---@field max_height number
---@field wrap boolean
---@field border any
---@field zindex number
---@field show_title boolean
---@field title_pos 'top-left'|'top-center'|'top-right'|'bottom-left'|'bottom-center'|'bottom-right'
---@field title_format string
---@field on_open? fun(win: number, buf: number)
---@field on_close? fun()

---@class PreviewConfigSetup: PreviewConfig

---@alias PreviewKeymapFn fun(params: PreviewKeymapFnParams)

---@class PreviewKeymapFnParams
---@field node NvimTreeNode

---@class PreviewManager
---@field instance? Preview
---@field watch_augroup? number
---@field watch_tree_buf? number
