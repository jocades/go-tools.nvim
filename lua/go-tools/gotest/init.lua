local TestView = require("go-tools.gotest.view")
local log = require("go-tools.log")("gotest")
local q = require("go-tools.query")
local u = require("go-tools.util")

local M = {}

---@class gotest.Opts
---@field split? "top"|"bottom"|"left"|"right"

---@type gotest.Opts
local user_opts = {
  split = "bottom",
}

local ns = vim.api.nvim_create_namespace("go-tools.gotest")
local group = vim.api.nvim_create_augroup("go-tools.gotest", { clear = true })

---@param path string
local function is_go_test(path)
  return path:match("_test.go$")
end

---@type gotest.View
local view
---@type gotest.Popup
local popup

local function start()
  if not view then
    view = TestView()
  end
  if not popup then
    popup = require("go-tools.gotest.popup")()
    popup:on("WinLeave", function()
      popup:hide()
    end)
  end
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

  local node = q.get_test_func_node(entry.Test, s.buf)
  assert(node, "Cannot find test node " .. vim.inspect(entry))
  local ln, col = node:range()

  ---@class gotest.Test
  s.tests[make_key(entry)] = {
    pkg = entry.Package,
    name = entry.Test,
    line = ln + 1,
    col = col + 1,
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
    ("Press '%sr' to run this test, '%ss' to show the output."):format(
      vim.g.mapleader,
      vim.g.mapleader
    ),
    "CursorLineSign",
  },
}

---@param test gotest.Test
---@param show fun(): nil
local function show_func_output(test, show)
  popup.border:set_text("top", ("[%s]"):format(test.name:sub(5)), "center")

  local width = 40
  for _, line in ipairs(test.output) do
    width = math.max(width, #line)
  end
  popup:set_size({ width = width + 2, height = #test.output + 2 })

  popup:map("n", "s", function()
    popup:hide()
    show()
  end)

  if not popup.bufnr then
    popup:map("n", "q", function()
      popup:hide()
    end)
  end

  popup:set_lines(test.output)
end

---@class gotest.execute.Opts
---@field buf? number
---@field name? string
---@field split? string

---@param opts? gotest.execute.Opts
local function execute(opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)
  if not is_go_test(path) then
    log.warn("Not a test file: " .. path)
    return
  end

  start()

  ---@class gotest.State
  local state = {
    pkg = "",
    buf = buf,
    ---@type string[]
    output = {},
    ---@type gotest.Test[]
    tests = {},
  }

  local function show()
    view:update_layout({
      position = opts.split or user_opts.split,
      relative = "win",
      size = "25%",
    })
    view:set_lines(state.output)
  end

  vim.api.nvim_buf_create_user_command(buf, "GoTestShow", function()
    show()
  end, {})

  vim.api.nvim_buf_create_user_command(buf, "GoTestShowFunc", function()
    local func = q.get_test_func_name_at_cursor(buf)
    local key = ("%s/%s"):format(state.pkg, func)
    local test = state.tests[key]
    if test then
      show_func_output(test, show)
    end
  end, {})

  vim.keymap.set("n", "<leader>r", function()
    M.run_func()
  end, { buffer = buf, desc = "Run test at cursor", nowait = true })

  vim.keymap.set(
    "n",
    "<leader>s",
    vim.cmd.GoTestShowFunc,
    { buffer = buf, desc = "Show test func output", nowait = true }
  )

  vim.keymap.set(
    "n",
    "<leader>S",
    vim.cmd.GoTestShow,
    { buffer = buf, desc = "Show test output", nowait = true }
  )

  local cmd = { "go", "test", "-json" }
  if opts.name then
    table.insert(cmd, "-run")
    table.insert(cmd, opts.name)
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
      u.ins(view.bufnr)
      u.ins(state)
    end, {})
  end
end

---@param opts? gotest.execute.Opts
function M.run(opts)
  execute(opts)
end

---@param opts? gotest.execute.Opts
function M.run_func(opts)
  if opts and opts.name then
    return execute(opts)
  end
  local name = q.get_test_func_name_at_cursor()
  if not name then
    log.warn("No 'TestFunc' found at cursor.")
    return
  end
  execute(u.extend(opts or {}, { name = name }))
end

---@param opts gotest.Opts
function M.setup(opts)
  u.merge(user_opts, opts or {})

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*_test.go",
    group = group,
    callback = function(e)
      vim.api.nvim_buf_create_user_command(e.buf, "GoTest", function(args)
        M.run()
      end, { nargs = "*" })

      vim.api.nvim_buf_create_user_command(e.buf, "GoTestFunc", function()
        M.run_func()
      end, {})

      vim.keymap.set(
        "n",
        "<leader>gt",
        vim.cmd.GoTestFunc,
        { buffer = e.buf, desc = "Run test at cursor" }
      )

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
