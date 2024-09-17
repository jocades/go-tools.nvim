local NuiPopup = require("nui.popup")
local u = require("go-tools.util")

---@class gotest.Popup: NuiPopup
---@overload fun(opts?: nui_popup_options): gotest.Popup
local Popup = NuiPopup:extend("Popup")

---@param opts? nui_split_options
function Popup:init(opts)
  Popup.super.init(
    self,
    u.extend({
      relative = "cursor",
      position = 0,
      -- position = {
      --   row = 0,
      --   col = 3,
      -- },
      size = {
        width = 60,
        height = 20,
      },
      enter = true,
      focusable = true,
      zindex = 50,
      border = {
        padding = {
          top = 1,
          left = 1,
        },
        style = "rounded",
        text = {
          top = " gotest ",
          top_align = "center",
          bottom = " 'q' close | 's' show in split ",
          bottom_align = "right",
        },
      },
      buf_options = {
        modifiable = true,
        readonly = false,
      },
      win_options = {
        -- winblend = 10,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
      },
    }, opts or {})
  )

  self:map("n", "q", function()
    self:hide()
  end)
end

---@param data string[]
function Popup:set_lines(data)
  self:show()
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, data)
end

---@param size number|string|nui_layout_option_size
function Popup:set_size(size)
  self:update_layout({
    relative = "cursor",
    position = 0,
    size = size,
  })
end

--[[ local pop = Popup()

local lines = {
  "=== RUN   TestCanAddNumbers",
  "math_test.go:16: for some reason 5 does weird stuff: can't add 5",
  "--- FAIL: TestCanAddNumbers (0.00s)",
}

local _ = "here!"

vim.keymap.set("n", "<leader>l", function()
  pop:update_layout({
    relative = {
      type = "buf",
      position = {
        row = 74,
        col = 16,
      },
    },
    -- position = "relative",
  })
  pop:set(lines)
end, { buffer = 0, nowait = true }) ]]

return Popup
