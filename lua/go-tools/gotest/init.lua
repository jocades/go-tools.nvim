local q = require("go-tools.gotest.query")
local u = require("go-tools.util")

local M = {}

local ns = vim.api.nvim_create_namespace("gotest")
local group = vim.api.nvim_create_augroup("gotest", { clear = true })

---@param entry go_test.Entry
local function make_key(entry)
  assert(entry.Package, "Must have Package:" .. vim.inspect(entry))
  assert(entry.Test, "Must have Test:" .. vim.inspect(entry))
  return ("%s/%s"):format(entry.Package, entry.Test)
end

---@param entry go_test.RunEntry
local function add_test(s, entry)
  s.tests[make_key(entry)] = {
    pkg = entry.Package,
    name = entry.Test,
    line = q.get_test_line(s.buf, entry.Test),
    output = {},
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

---@param s go_test.exec.State
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
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  ---@class go_test.exec.State
  local state = {
    buf = buf,
    out_buf = -1,
    tests = {},
  }

  vim.api.nvim_buf_create_user_command(buf, "GoTestDiag", function()
    local line = vim.fn.line(".")
    u.ins(state.tests)
    for _, test in pairs(state.tests) do
      if test.line == line then
        if state.out_buf == -1 then
          state.out_buf = vim.api.nvim_create_buf(false, true)
          vim.cmd.split()
          vim.api.nvim_set_current_buf(state.out_buf)
          vim.api.nvim_win_set_height(0, 12)
        end
        vim.api.nvim_buf_set_lines(state.out_buf, 0, -1, false, test.output)
      end
    end
  end, {})

  vim.fn.jobstart(table.concat(cmd, " "), {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then
        return
      end
      for _, line in ipairs(data) do
        parse_line(state, line)
      end
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

      u.ins(state)

      vim.diagnostic.set(ns, buf, diagnostics, {
        virtual_text = {
          spacing = 4,
          prefix = " ",
          -- prefix = "●",
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

  local func = q.get_test_func_at_cursor(buf)
  u.ins(func, true)

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
