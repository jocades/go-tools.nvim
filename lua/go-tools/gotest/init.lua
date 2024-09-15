local TestView = require("go-tools.gotest.view")
local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

local ns = vim.api.nvim_create_namespace("go-tools.gotest")
-- local group = vim.api.nvim_create_augroup("go-tools.gotest", { clear = true })

---@type gotest.Session
local session
local function start_session()
  if not session then
    ---@class gotest.Session
    session = {
      view = TestView(),
    }
  end
  return vim.api.nvim_get_current_buf()
end

---@param entry gotest.Entry
local function make_key(entry)
  assert(entry.Package, "Must have Package:" .. vim.inspect(entry))
  assert(entry.Test, "Must have Test:" .. vim.inspect(entry))
  return ("%s/%s"):format(entry.Package, entry.Test)
end

---@param entry gotest.RunEntry
local function add_test(s, entry)
  if s.pkg == "" then
    s.pkg = entry.Package
  end

  ---@class gotest.Test
  s.tests[make_key(entry)] = {
    pkg = entry.Package,
    line = q.get_test_line(s.buf, entry.Test),
    output = {},
    success = false,
  }
end

---@param s gotest.State
---@param entry gotest.OutputEntry
local function add_output(s, entry)
  local output = vim.trim(entry.Output)
  if entry.Test then
    table.insert(s.tests[make_key(entry)].output, output)
  end
  table.insert(s.output, output)
end

---@param s gotest.State
---@param entry gotest.DoneEntry
local function mark_success(s, entry)
  s.tests[make_key(entry)].success = entry.Action == "pass"
end

---@param s gotest.State
---@param line string
local function parse_line(s, line)
  local ok, decoded = pcall(vim.json.decode, line)
  if not ok then
    return
  end

  if decoded.Action == "run" then
    add_test(s, decoded)
  elseif decoded.Action == "output" then
    add_output(s, decoded)
  elseif decoded.Action == "pass" or decoded.Action == "fail" then
    if decoded.Test then
      mark_success(s, decoded)
    end
    -- ...
  end
end

local virt_lines = {
  {
    ("Press '%st' to run the test, '%so' to show output."):format(
      vim.g.mapleader,
      vim.g.mapleader
    ),
    "CursorLineSign",
  },
}

---@param state gotest.State
local function gotest(state)
  ---@param p vim.SystemCompleted
  return function(p)
    local lines = vim.split(p.stdout, "\n", { trimempty = true })

    for _, line in ipairs(lines) do
      parse_line(state, line)
    end

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

      vim.api.nvim_buf_set_extmark(state.buf, ns, test.line - 2, 0, {
        virt_lines = { virt_lines },
      })
    end

    vim.diagnostic.set(ns, state.buf, diagnostics, {
      virtual_text = {
        spacing = 2,
        prefix = " ",
      },
    })
  end
end

---@param buf number
---@param cmd string[]
local function execute(buf, cmd)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  ---@class gotest.State
  local state = {
    pkg = "",
    buf = buf,
    ---@type string[]
    output = {},
    ---@type gotest.Test[]
    tests = {},
  }

  vim.system(cmd, { text = true }, vim.schedule_wrap(gotest(state)))

  vim.api.nvim_buf_create_user_command(buf, "GoTestShowFunc", function()
    local func = q.get_test_func_at_cursor(buf)
    local key = ("%s/%s"):format(state.pkg, func)
    local test = state.tests[key]
    if test then
      return
    end
    session.view:set(test.output)
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestShow", function()
    session.view:set(state.output)
  end, {})

  vim.keymap.set("n", "<leader>t", function()
    M.go_test_func(buf)
  end, { buffer = buf, desc = "Run test at cursor" })

  vim.keymap.set(
    "n",
    "<leader>o",
    vim.cmd.GoTestShowFunc,
    { buffer = buf, desc = "Show test output" }
  )

  if vim.env.DEBUG == "go-test" then
    vim.api.nvim_buf_create_user_command(buf, "GoTestDebug", function()
      u.title("go_test dbg")
      u.ins(session.view.bufnr)
      u.ins(state)
      vim.cmd.Noice()
    end, {})
  end
end

---@param path string
local function is_go_test(path)
  return path:match("_test.go$")
end

---@param buf number
local function get_path(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if is_go_test(path) then
    return path
  end
end

---@param buf number
function M.go_test(buf, path)
  path = path or get_path(buf)
  if path then
    execute(buf, { "go", "test", "-json", path })
  end
end

---@param buf number
---@param name? string
function M.go_test_func(buf, name)
  local path = get_path(buf)
  if not path then
    return
  end

  if not name then
    name = q.get_test_func_at_cursor(buf)
    if not name then
      u.warn("No 'TestFunc' found at cursor.", "gotest")
      return
    end
  end

  execute(buf, { "go", "test", "-json", "-run", name, path })
end

function M.setup()
  vim.api.nvim_create_user_command("GoTest", function()
    local buf = start_session()
    M.go_test(buf)
  end, {})

  vim.api.nvim_create_user_command("GoTestFunc", function()
    local buf = start_session()
    M.go_test_func(buf)
  end, {})

  --[[ vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*_test.go",
    callback = function(e)
    end,
  }) ]]
end

return M
