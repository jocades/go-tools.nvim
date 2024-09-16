local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

---@param args string[]
local function Command(args, opts)
  opts = opts or {}

  local cmd = {
    _map = {},
  }

  ---@param key string
  ---@param val string
  function cmd:flag(key, val)
    key = (opts.flag_prefix or "-") .. key
    self._map[key] = val
  end

  ---@param arg? string
  function cmd:build(arg)
    for k, v in pairs(self._map) do
      table.insert(args, k)
      table.insert(args, v)
    end

    if arg then
      table.insert(args, arg)
    end

    return args
  end

  return cmd
end

function M.setup()
  ---@param opts vim.user_command.Opts
  vim.api.nvim_create_user_command("GoTagsAdd", function(opts)
    local buf = vim.api.nvim_get_current_buf()

    local struct = q.get_struct_at_cursor(buf)
    if not struct then
      return
    end

    local cmd = Command({ "gomodifytags", "-format", "json" })

    local path = vim.api.nvim_buf_get_name(buf)
    local tags = opts.fargs[1] or "json"

    cmd:flag("struct", struct)
    cmd:flag("file", path)
    cmd:flag("add-tags", tags)

    local command = cmd:build()

    u.ins(command)

    vim.system(cmd:build(), { text = true }, function(p)
      if not vim.startswith(p.stdout, "{") then
        u.err(p.stdout)
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

---@class vim.user_command.Opts
---@field name string
---@field fargs string[]
---@field bang boolean
---@field line1 number
---@field line2 number
---@field range number
---@field count number
---@field smods table

---@param opts vim.user_command.Opts
vim.api.nvim_create_user_command("GoUser", function(opts)
  u.ins(opts.fargs)
end, { nargs = "?" })

return M
