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

return TestView
