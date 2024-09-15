local TestView = require("go-tools.gotest.view")
local q = require("go-tools.query")
local time = require("go-tools.gotest.time")
local u = require("go-tools.util")

local M = {}

local ns = vim.api.nvim_create_namespace("gotest")
local group = vim.api.nvim_create_augroup("gotest", { clear = true })

---@type gotest.Session
local session
local function start_session()
  if not session then
    ---@class gotest.Session
    session = {
      view = TestView(),
    }
  end
  return vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0)
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

    u.dbg(state)

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

  vim.api.nvim_buf_create_user_command(buf, "GoTestDebug", function()
    print("==== go-test dbg ====")
    u.ins(session.view.bufnr)
    u.ins(state)
    vim.cmd.Noice()
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestShowFunc", function()
    local func = q.get_test_func_at_cursor(buf)
    local key = ("%s/%s"):format(state.pkg, func)
    local test = state.tests[key]
    if not test then
      return
    end
    session.view:set(test.output)
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestShow", function()
    session.view:set(state.output)
  end, {})

  vim.keymap.set(
    "n",
    "<leader>o",
    vim.cmd.GoTestShowFunc,
    { buffer = buf, desc = "Show test output" }
  )

  vim.keymap.set("n", "<leader>t", function()
    M.go_test_func(buf)
  end, { buffer = buf, desc = "Run test at cursor" })
end

---@param buf number
local function get_path(buf)
  local path = vim.api.nvim_buf_get_name(buf)
  if u.is_go_test(path) then
    return path
  end
end

---@param buf number
---@param path? string
function M.go_test(buf, path)
  path = path or get_path(buf)
  if path then
    execute(buf, { "go", "test", "-json", path })
  end
end

---@param buf number
---@param path? string
function M.go_test_func(buf, path)
  path = path or get_path(buf)
  if not path then
    return
  end

  local func, line = q.get_test_func_at_cursor(buf)
  u.ins({ func, line }, true)
  if not func then
    return
  end

  execute(buf, { "go", "test", "-json", "-run", func, path })
end

local function set_help(buf)
  local nodes = q.get_nodes(
    buf,
    q.go_test_func_query_str:format('#match? @_func_name "^Test"'),
    "_func_name"
  )

  if not nodes then
    return
  end

  for _, node in ipairs(nodes) do
    vim.print(vim.treesitter.get_node_text(node, buf))

    vim.api.nvim_buf_set_extmark(buf, ns, node:range() - 1, 0, {
      virt_lines = { virt_lines },
    })
  end
end

function M.setup()
  vim.print("hello")

  local dw = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "gotools")
  if not vim.uv.fs_stat(dw) then
    vim.fn.mkdir(dw)
  end

  vim.api.nvim_create_user_command("GoTest", function()
    local buf, _ = start_session()
    M.go_test(buf)
  end, {})

  vim.api.nvim_create_user_command("GoTestFunc", function()
    M.go_test_func(vim.api.nvim_get_current_buf())
  end, {})

  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = "*_test.go",
        callback = function(e)
          vim.notify("buf read post")
          -- set_help(e.buf)
        end,
      })
    end,
  })
end

return M
