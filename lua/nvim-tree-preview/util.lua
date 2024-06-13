local M = {}

---Returns true if the given value is a function or a table with a __call metamethod.
---@param val any
---@return boolean
M.is_callable = function(val)
  local t = type(val)
  if t == 'function' then
    return true
  end
  if t == 'table' then
    local mt = getmetatable(val)
    return mt and M.is_callable(mt.__call)
  end
  return false
end

return M
