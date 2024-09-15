local Popup = require("nui.popup")

local M = {}

function M.create_popup(title)
  return Popup({
    relative = "editor",
    -- enter = true,
    focusable = true,
    position = {
      row = "90%",
      col = "99%",
    },
    size = {
      width = 50,
      height = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
        bottom = "rerun (r) | close (q) | save (s)",
        bottom_align = "center",
      },
    },
    buf_options = {
      -- modifiable = false,
      -- readonly = true,
    },
  })
end

---@param buf number
local function clear_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

-- Execute shell command using vim.fn.system
---@param exec string | table { string }
function M.sys(exec, debug)
  if type(exec) == "table" then
    exec = table.concat(exec, " && ")
  end
  if debug then
    vim.print("Executing: " .. exec)
  end
  vim.fn.system(exec)
end

return M

--[[ local function append_data(buf, data)
  if not data then
    return
  end
  vim.api.nvim_buf_set_lines(buf, -2, -1, false, data)
end ]]

--[[ vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('jvim-go-test', { clear = true }),
  pattern = '*_test.go',
  callback = execute,
}) ]]
