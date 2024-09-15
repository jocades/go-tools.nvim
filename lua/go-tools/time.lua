local M = {}

---@param interval number
---@param callback fun()
function M.set_interval(interval, callback)
  local timer = vim.uv.new_timer()
  timer:start(interval, interval, function()
    callback()
  end)
  return timer
end

---@param timer uv_timer_t
function M.clear_interval(timer)
  timer:stop()
  timer:close()
end

function M.track() end

return M
