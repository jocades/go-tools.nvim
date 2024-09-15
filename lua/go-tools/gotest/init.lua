local Split = require("nui.split")
local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

local ns = vim.api.nvim_create_namespace("gotest")
local group = vim.api.nvim_create_augroup("gotest", { clear = true })

local function create_split()
  return Split({
    enter = false,
    relative = "editor",
    position = "bottom",
    size = "20%",
  })
end

local session = {
  ---@type NuiSplit
  split = nil,
}

-- unmount component when cursor leaves buffer
-- split:on(event.BufLeave, function()
--   split:unmount()
-- end)

---@param entry go_test.Entry
local function make_key(entry)
  assert(entry.Package, "Must have Package:" .. vim.inspect(entry))
  assert(entry.Test, "Must have Test:" .. vim.inspect(entry))
  return ("%s/%s"):format(entry.Package, entry.Test)
end

---@param entry go_test.RunEntry
local function add_test(s, entry)
  if s.pkg == "" then
    s.pkg = entry.Package
  end

  ---@class go_test.Test
  s.tests[make_key(entry)] = {
    pkg = entry.Package,
    line = q.get_test_line(s.buf, entry.Test),
    output = {},
    success = false,
  }
end

---@param entry go_test.OutputEntry
local function add_output(s, entry)
  table.insert(s.tests[make_key(entry)].output, vim.trim(entry.Output))
end

---@param entry go_test.DoneEntry
local function mark_success(s, entry)
  s.tests[make_key(entry)].success = entry.Action == "pass"
end

---@param path string
local function is_go_test(path)
  return path:match("_test.go$")
end

---@param buf number
local function clear(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
end

---@param s go_test.State
---@param line string
local function parse_line(s, line)
  if vim.trim(line) == "" then
    return
  end

  local ok, decoded = pcall(vim.json.decode, line)
  if not ok or not decoded.Test then
    return
  end

  if decoded.Action == "run" then
    add_test(s, decoded)
  elseif decoded.Action == "output" then
    add_output(s, decoded)
  elseif decoded.Action == "pass" or decoded.Action == "fail" then
    mark_success(s, decoded)
  end
end

---@param buf number
---@param cmd string[]
local function execute(buf, cmd)
  if not session.split then
    session.split = create_split()
  end

  ---@class go_test.State
  local state = {
    pkg = "",
    buf = buf,
    ---@type go_test.Test[]
    tests = {},
  }

  vim.api.nvim_buf_create_user_command(buf, "GoTestDebug", function()
    print("==== go-test dbg ====")
    u.ins(session.split.bufnr)
    u.ins(state, true)
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestDiag", function()
    local func = q.get_test_func_at_cursor(buf)
    local key = ("%s/%s"):format(state.pkg, func)
    local test = state.tests[key]
    if not test then
      return
    end
    session.split:mount()
    vim.api.nvim_buf_set_lines(session.split.bufnr, 0, -1, false, test.output)
  end, {})

  vim.fn.jobstart(table.concat(cmd, " "), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then
        return
      end
      u.ins(data)

      for _, line in ipairs(data) do
        parse_line(state, line)
      end
    end,
    on_stderr = function(_, data)
      local out = table.concat(data, "\n")
      if vim.trim(out) == "" then
        return
      end
      u.err(table.concat(data, "\n"))
    end,
    on_exit = function()
      ---@type vim.Diagnostic[]
      local diagnostics = {}
      for _, test in pairs(state.tests) do
        if test.success then
          table.insert(diagnostics, {
            lnum = test.line - 1,
            col = 0,
            severity = vim.diagnostic.severity.INFO,
            source = "gotest",
            message = "PASS",
          })
        else
          table.insert(diagnostics, {
            lnum = test.line - 1,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            source = "gotest",
            message = "FAIL",
          })
        end
      end

      u.dbg(state)

      vim.diagnostic.set(ns, buf, diagnostics, {
        virtual_text = {
          spacing = 0,
          prefix = " ",
        },
      })
    end,
  })
end

---@param buf number
function M.go_test(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if not is_go_test(path) then
    return
  end

  execute(buf, { "go", "test", "-json", path })
end

---@param buf number
function M.go_test_func(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if not is_go_test(path) then
    return
  end

  local func, line = q.get_test_func_at_cursor(buf)
  u.ins({ func, line }, true)

  if not func then
    return
  end

  execute(buf, { "go", "test", "-json", "-run", func, path })
end

function M.setup()
  vim.api.nvim_create_user_command("GoTest", function()
    M.go_test(vim.api.nvim_get_current_buf())
  end, {})

  vim.api.nvim_create_user_command("GoTestFunc", function()
    M.go_test_func(vim.api.nvim_get_current_buf())
  end, {})
end

return M
