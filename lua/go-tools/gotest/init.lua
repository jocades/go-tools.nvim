local TestView = require("go-tools.gotest.view")
local log = require("go-tools.log")("gotest")
local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

local ns = vim.api.nvim_create_namespace("go-tools.gotest")
local group = vim.api.nvim_create_augroup("go-tools.gotest", { clear = true })

---@param path string
local function is_go_test(path)
  return path:match("_test.go$")
end

---@type gotest.Session
local session
local function start_session()
  local path = vim.api.nvim_buf_get_name(0)
  if not is_go_test(path) then
    return
  end
  if not session then
    ---@class gotest.Session
    session = {
      view = TestView(),
    }
  end
  return vim.api.nvim_get_current_buf(), path
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
    line = q.get_test_line(entry.Test, s.buf),
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
    ("Press '%sr' to run the test, '%ss' to show output."):format(
      vim.g.mapleader,
      vim.g.mapleader
    ),
    "CursorLineSign",
  },
}

---@param name? string
local function execute(name)
  local buf, path = start_session()
  if not buf then
    return
  end

  ---@class gotest.State
  local state = {
    pkg = "",
    buf = buf,
    ---@type string[]
    output = {},
    ---@type gotest.Test[]
    tests = {},
  }

  vim.api.nvim_buf_create_user_command(buf, "GoTestShow", function()
    session.view:set(state.output)
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestShowFunc", function()
    local func = q.get_test_func_name_at_cursor(buf)
    local key = ("%s/%s"):format(state.pkg, func)
    local test = state.tests[key]
    if test then
      session.view:set(test.output)
    end
  end, {})

  vim.keymap.set("n", "<leader>r", function()
    M.run_func()
  end, { buffer = buf, desc = "Run test at cursor", nowait = true })

  vim.keymap.set(
    "n",
    "<leader>s",
    vim.cmd.GoTestShowFunc,
    { buffer = buf, desc = "Show test output", nowait = true }
  )

  local cmd = { "go", "test", "-json" }
  if name then
    table.insert(cmd, "-run")
    table.insert(cmd, name)
  end
  table.insert(cmd, path)

  vim.system(cmd, { text = true }, function(p)
    local lines = vim.split(p.stdout, "\n", { trimempty = true })

    vim.schedule(function()
      for _, line in ipairs(lines) do
        parse_line(state, line)
      end

      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

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
    end)
  end)

  if vim.env.DEBUG == "go-test" then
    vim.api.nvim_buf_create_user_command(buf, "GoTestDebug", function()
      u.title("go_test dbg")
      u.ins(session.view.bufnr)
      u.ins(state)
    end, {})
  end
end

function M.run()
  execute()
end

function M.run_func()
  local name = q.get_test_func_name_at_cursor()
  if not name then
    log.warn("No 'TestFunc' found at cursor.")
    return
  end

  execute(name)
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*_test.go",
    group = group,
    callback = function(e)
      vim.api.nvim_buf_create_user_command(e.buf, "GoTest", function()
        M.run()
      end, {})

      vim.api.nvim_buf_create_user_command(e.buf, "GoTestFunc", function()
        M.run_func()
      end, {})

      local id
      vim.api.nvim_buf_create_user_command(e.buf, "GoTestOnSave", function(args)
        -- Detach
        if args.bang and id then
          vim.api.nvim_del_autocmd(id)
          id = nil
          return
        end

        -- Attach
        if not args.bang then
          if not id then
            M.run()
          end

          id = vim.api.nvim_create_autocmd("BufWritePost", {
            buffer = e.buf,
            callback = function()
              M.run()
            end,
          })
        end
      end, { bang = true })
    end,
  })
end

return M
