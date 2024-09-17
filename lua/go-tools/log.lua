---@param title? string
local function Logger(title)
  local opts = { title = title or "go-tools" }
  return {
    ---@param msg string
    info = function(msg)
      vim.notify(msg, vim.log.levels.INFO, opts)
    end,
    ---@param msg string
    warn = function(msg)
      vim.notify(msg, vim.log.levels.WARN, opts)
    end,
    ---@param msg string
    error = function(msg)
      vim.notify(msg, vim.log.levels.ERROR, opts)
    end,
  }
end

return Logger
