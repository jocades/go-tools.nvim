---@param title? string
local function Logger(title)
  return {
    ---@param msg string
    info = function(msg)
      vim.notify(msg, vim.log.levels.INFO, { title = title or "go-tools" })
    end,
    ---@param msg string
    warn = function(msg)
      vim.notify(msg, vim.log.levels.WARN, { title = title or "go-tools" })
    end,
    ---@param msg string
    error = function(msg)
      vim.notify(msg, vim.log.levels.ERROR, { title = title or "go-tools" })
    end,
  }
end

return Logger
