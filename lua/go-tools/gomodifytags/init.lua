local q = require("go-tools.query")

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("GoTags", function()
    local struct = q.get_struct_at_cursor(vim.api.nvim_get_current_buf())
    print("struct -->", struct)
  end, {})
end

return M
