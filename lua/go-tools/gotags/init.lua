local Command = require("go-tools.cmd")
local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

---@type gotags.Opts
local user_opts = {
  tags = "json",
  transform = "camelcase",
  template = nil,
}

---@class gotags.Opts
---@field tags? string|string[]
---@field template? string
---@field transform? "snakecase"|"camelcase"|"lispcase"|"pascalcase"|"titlecase"|"keep"

---@class gotags.action.Opts : gotags.Opts
---@field range? [number,number]

---@class gotags.execute.Opts : gotags.action.Opts
---@field action "add-tags"|"remove-tags"|"clear-tags"

---@param opts gotags.execute.Opts
local function execute(opts)
  u.dbg(opts)
  local buf = vim.api.nvim_get_current_buf()
  local cmd = Command({ "gomodifytags", "-format", "json" })

  if not opts.range then
    local struct = q.get_struct_name_at_cursor(buf)
    if not struct then
      u.warn("No struct found at cursor")
      return
    end
    cmd:flag("struct", struct)
  else
    cmd:flag("line", table.concat(opts.range, ","))
  end

  cmd:flag("file", vim.api.nvim_buf_get_name(buf))
  cmd:flag("transform", opts.transform)
  if opts.template then
    cmd:flag("template", opts.template)
  end

  if opts.action == "clear-tags" then
    cmd:arg("-" .. opts.action)
  else
    cmd:flag(opts.action, u.to_csv(opts.tags))
  end

  u.dbg(cmd:build())

  cmd:spawn(function(p)
    if p.code ~= 0 then
      u.err(p.stderr, "gotags")
      return
    end

    local ok, decoded = pcall(vim.json.decode, p.stdout)
    if not ok or not decoded then
      return
    end ---@cast decoded { start: number, end: number, lines: string[] }

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
end

---@param opts? gotags.action.Opts
function M.add(opts)
  execute(u.merge(user_opts, opts or {}, { action = "add-tags" }))
end

---@param opts? gotags.action.Opts
function M.remove(opts)
  execute(u.merge(user_opts, opts or {}, { action = "remove-tags" }))
end

---@param opts? { range: [number,number] }
function M.clear(opts)
  opts = opts or {} ---@cast opts gotags.execute.Opts
  opts.action = "clear-tags"
  execute(opts)
end

local user_cmd_args = {
  "tags",
  "transform",
  "template",
}

---Parse key value pairs passed by a user_command.
---':GoTagsAdd tags=json,xml transform=camelcase'
---@param opts vim.user_command.Opts
local function parse(opts)
  ---@type gotags.action.Opts
  local out = {}
  for _, arg in ipairs(opts.fargs) do
    local k, v = unpack(vim.split(arg, "="))
    if vim.tbl_contains(user_cmd_args, k) then
      out[k] = v
    else
      u.warn(("Unknown option: %s"):format(k))
      return
    end
  end
  -- If range is 0: no selection, else if 2: line or block selected.
  if opts.range == 2 then
    out.range = { opts.line1, opts.line2 }
  end
  return out
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.go",
    callback = function(e)
      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsAdd", function(opts)
        opts = parse(opts)
        if opts then
          M.add(opts)
        end
      end, { nargs = "*", range = true })

      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsRemove", function(opts)
        opts = parse(opts)
        if opts then
          M.remove(opts)
        end
      end, { nargs = "*", range = true })

      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsClear", function(opts)
        opts = parse(opts)
        if opts then
          M.clear(opts)
        end
      end, { nargs = "*", range = true })
    end,
  })
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

return M