local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("GoTags", function()
    local buf = vim.api.nvim_get_current_buf()

    local struct = q.get_struct_at_cursor(buf)
    if not struct then
      return
    end

    vim.system({
      "gomodifytags",
      "-format",
      "json",
      "-file",
      vim.api.nvim_buf_get_name(buf),
      "-struct",
      struct,
      "-add-tags",
      "json",
    }, { text = true }, function(p)
      if not vim.startswith(p.stdout, "{") then
        return
      end

      ---@type { start: number, end: number, lines: string[] }
      local decoded = vim.json.decode(p.stdout)

      vim.schedule(function()
        vim.api.nvim_buf_set_lines(
          buf,
          decoded.start - 1,
          decoded["end"],
          false,
          decoded.lines
        )
      end)
    end)
  end, {})
end

return M
