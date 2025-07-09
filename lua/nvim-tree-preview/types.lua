---@class NvimTreeNode
---@field absolute_path string
---@field executable boolean
---@field extension string
---@field filetype string
---@field link_to string
---@field name string
---@field type 'file' | 'directory' | 'link'

---@class PreviewImage
---@field clear fun()

---@class Preview
---@field manager PreviewManager
---@field augroup number?
---@field preview_win number?
---@field preview_buf number?
---@field tree_win number?
---@field tree_buf number?
---@field tree_node NvimTreeNode?
---@field image PreviewImage?

---@alias PreviewKeymapOpenDirection 'edit'|'tab'|'vertical'|'horizontal'
---@alias PreviewKeymapActionClose {action: 'close', focus_tree?: boolean, unwatch?: boolean}
---@alias PreviewKeymapActionToggleFocus {action: 'toggle_focus'}
---@alias PreviewKeymapActionSelectNode {action: 'select_node', target: 'next'|'prev'}
---@alias PreviewKeymapAction PreviewKeymapActionClose|PreviewKeymapActionToggleFocus|PreviewKeymapActionSelectNode
---@alias PreviewKeymap string|function|PreviewKeymapAction|{open: PreviewKeymapOpenDirection}
---@alias PreviewKeymapSpec {[1]: string, [2]: PreviewKeymap}

---@class WindowPosition
---@field row? number|fun(tree_win?: number, size?: {width: number, height: number}): number
---@field col? number|fun(tree_win?: number, size?: {width: number, height: number}): number

---@class PreviewConfig
---@field keymaps {[string]: PreviewKeymap}
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
---@field follow_links boolean
---@field win_position WindowPosition
---@field on_open? fun(win: number, buf: number)
---@field on_close? fun()
---@field image_preview {enable: boolean, patterns: string[]}

---@class PreviewConfigSetup: PreviewConfig

---@alias PreviewKeymapFn fun(params: PreviewKeymapFnParams)

---@class PreviewKeymapFnParams
---@field node NvimTreeNode

---@class PreviewManager
---@field instance? Preview
---@field watch_augroup? number
---@field watch_tree_buf? number
