local Command = require("go-tools.cmd")
local log = require("go-tools.log")("gotags")
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
  local buf = vim.api.nvim_get_current_buf()
  local cmd = Command({ "gomodifytags", "-format", "json" })

  if not opts.range then
    local struct = q.get_struct_name_at_cursor(buf)
    if not struct then
      u.log.warn("No struct found at cursor")
      return
    end
    cmd:opt("struct", struct)
  else
    cmd:opt("line", u.to_csv(opts.range))
  end

  cmd:opt("file", vim.api.nvim_buf_get_name(buf))

  if opts.action == "clear-tags" then
    cmd:opt(opts.action)
  else
    cmd:opt(opts.action, u.to_csv(opts.tags))
  end

  cmd:optif("transform", opts.transform)
  cmd:optif("template", opts.template)

  cmd:spawn(function(p)
    if p.code ~= 0 then
      log.error(p.stderr)
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
  execute(u.extend(user_opts, opts or {}, { action = "add-tags" }))
end

---@param opts? gotags.action.Opts
function M.remove(opts)
  execute(u.extend(user_opts, opts or {}, { action = "remove-tags" }))
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
---@param args vim.user_command.Args
local function parse(args)
  ---@type gotags.action.Opts
  local opts = {}
  for _, arg in ipairs(args.fargs) do
    local k, v = unpack(vim.split(arg, "="))
    if vim.tbl_contains(user_cmd_args, k) then
      opts[k] = v
    else
      log.warn(("Unknown option: %s"):format(k))
      return
    end
  end
  -- If range is 0: no selection, else if 2: line or block selected.
  if args.range == 2 then
    opts.range = { args.line1, args.line2 }
  end
  return opts
end

local group = vim.api.nvim_create_augroup("go-tools.gotags", { clear = true })

---@param opts? gotags.Opts
function M.setup(opts)
  u.merge(user_opts, opts or {})

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.go",
    group = group,
    callback = function(e)
      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsAdd", function(args)
        args = parse(args)
        if args then
          M.add(args)
        end
      end, { nargs = "*", range = true })

      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsRemove", function(args)
        args = parse(args)
        if args then
          M.remove(args)
        end
      end, { nargs = "*", range = true })

      vim.api.nvim_buf_create_user_command(e.buf, "GoTagsClear", function(args)
        args = parse(args)
        if args then
          M.clear(args)
        end
      end, { nargs = "*", range = true })
    end,
  })
end

return M
