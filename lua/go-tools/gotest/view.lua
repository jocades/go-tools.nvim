local Split = require("nui.split")

---@class TestView : NuiSplit
---@overload fun(): TestView
local TestView = Split:extend("TestView")

function TestView:init(opts)
  TestView.super.init(
    self,
    vim.tbl_deep_extend("force", opts or {}, {
      relative = "editor",
      position = "bottom",
      size = "20%",
    })
  )
end

---@param data string[]
function TestView:set(data)
  self:show()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
end

--[[ ---@class View
---@overload fun(): View
local View = setmetatable({
  bufnr = -1,
}, {
  __index = function(t, k)
    if t[k] then
      return t[k]
    end
  end,
  __call = function()
    vim.print("call")
  end,
}) ]]

--[[ function View:show()
  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_create_autocmd("BufDelete", {
      buffer = self.bufnr,
      callback = function()
        self.bufnr = nil
      end,
    })
  end
end

---@param data string[]
function View:set(data)
  self:show()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
end

local x = View() ]]

return TestView
