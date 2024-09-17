local Split = require("nui.split")

---@class gotest.View : NuiSplit
---@overload fun(opts?: nui_split_options): gotest.View
local TestView = Split:extend("TestView")

---@param opts nui_split_options
function TestView:init(opts)
  TestView.super.init(
    self,
    vim.tbl_deep_extend("force", opts or {}, {
      enter = false,
      relative = "editor",
      position = "bottom",
      size = "20%",
    })
  )

  self:map("n", "q", vim.cmd.q)
end

---@param data string[]
function TestView:set_lines(data)
  self:show()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
end

return TestView
