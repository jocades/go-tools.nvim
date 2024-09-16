local Command = require("go-tools.cmd")
local u = require("go-tools.util")

local cmd = Command({ "gomodifytags", "-format", "json" })

---Parse key value pairs passed by a user_command.
---':GoTagsAdd tags=json,xml'
---@param fargs string[]
---@param c Command
local function parse(fargs, c)
  for _, o in ipairs(fargs) do
    local k, v = unpack(vim.split(o, "="))
    c:flag(k, v)
  end
end

---@param opts vim.user_command.Opts
vim.api.nvim_create_user_command("GoUser", function(opts)
  -- if range == 2 we have a start and end line for the range
  u.ins(opts)
  parse(opts.fargs, cmd)
end, { nargs = "*", range = true })
