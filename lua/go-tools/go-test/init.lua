local Popup = require("nui.popup")
local tsu = require("nvim-treesitter.ts_utils")
local u = require("go-tools.util")

local M = {}

---@class go_test.Entry
---@field Time string
---@field Action string
---@field Package string
---@field Test? string
---@field Output? string
---@field Elapsed? number

---@class go_test.StartEntry : go_test.Entry
---@field Action "start"

---@class go_test.RunEntry : go_test.Entry
---@field Action "run"
---@field Test string

---@class go_test.OutputEntry : go_test.Entry
---@field Action "output"
---@field Test string
---@field Output string

---@class go_test.DoneEntry : go_test.OutputEntry
---@field Action "pass" | "fail"
---@field Test string
---@field Elapsed number

---@class go_test.PassEntry : go_test.DoneEntry
---@field Action "pass"

---@class go_test.FailEntry : go_test.DoneEntry
---@field Action "fail"

local go_test_func_query_str = [[
  ((function_declaration
    name: (identifier) @_func_name
    parameters: (parameter_list
      (parameter_declaration
        name: (identifier)
        type: (pointer_type
          (qualified_type
            package: (package_identifier) @_pkg_name
            name: (type_identifier) @_type_name)))))
    (#eq? @_pkg_name "testing")
    (#eq? @_type_name "T")
    (#match? @_func_name "^Test"))
]]

local function parse_query(buf, query_str)
  local ft = vim.bo[buf].ft
  local lang = vim.treesitter.language.get_lang(ft)

  if not lang then
    u.err("No treesitter parser found for " .. ft)
    return
  end

  local root = vim.treesitter.get_parser(buf):parse()[1]:root()
  local query = vim.treesitter.query.parse(lang, query_str)

  print("===============")

  for i, node in query:iter_captures(root, buf) do
    local capture = query.captures[i]
    -- ins(capture)
    -- ins(getmetatable(capture))

    if capture == "_func_name" then
      local srow, scol, erow, ecol = node:range()
      local func_name = vim.treesitter.get_node_text(node, buf)

      vim.print({
        func_name = func_name,
        srow = srow,
        scol = scol,
        erow = erow,
        ecol = ecol,
      })
    end
  end
end

local ns = vim.api.nvim_create_namespace("go-test")
local group = vim.api.nvim_create_augroup("go-test", { clear = true })

---@param entry go_test.RunEntry
local function get_test_line(entry)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("func%s+" .. entry.Test .. "%s*%(") then
      return i
    end
  end

  error("Test not found: " .. entry.Test)
end

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
    line = get_test_line(entry),
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

---@param buf number
local function get_test_func_at_cursor(buf)
  local node = tsu.get_node_at_cursor()

  while node do
    if node:type() == "function_declaration" then
      node = node:named_child(0)
      break
    end
    node = node:parent()
  end

  if not node then
    return
  end

  local func = vim.treesitter.get_node_text(node, buf)
  if func:sub(1, 4) == "Test" then
    return func
  end
end

---@param s table
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

  local state = {
    buf = buf,
    out_buf = nil,
    tests = {},
  }

  vim.api.nvim_buf_create_user_command(buf, "GoTestDiag", function()
    local line = vim.fn.line(".")
    u.ins(line, true)
    for _, test in pairs(state.tests) do
      if test.line == line then
        if not state.out_buf then
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
    on_exit = function(_, code)
      ---@type vim.Diagnostic[]
      local diagnostics = {}

      for _, test in pairs(state.tests) do
        if test.success then
          table.insert(diagnostics, {
            lnum = test.line - 1,
            col = 0,
            severity = vim.diagnostic.severity.INFO,
            source = "go-test",
            message = "PASS",
          })
        else
          table.insert(diagnostics, {
            lnum = test.line - 1,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            source = "go-test",
            message = "FAIL",
          })
        end
      end

      u.ins(state)

      vim.diagnostic.set(ns, buf, diagnostics)
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

  local func = get_test_func_at_cursor(buf)
  u.ins(func)
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

--[[ local function append_data(buf, data)
  if not data then
    return
  end
  vim.api.nvim_buf_set_lines(buf, -2, -1, false, data)
end ]]

--[[ vim.api.nvim_create_autocmd('BufWritePost', {
  group = vim.api.nvim_create_augroup('jvim-go-test', { clear = true }),
  pattern = '*_test.go',
  callback = execute,
}) ]]

--[[ local function create_popup(title)
  return Popup({
    relative = "editor",
    -- enter = true,
    focusable = true,
    position = {
      row = "90%",
      col = "99%",
    },
    size = {
      width = 50,
      height = 20,
    },
    border = {
      style = "rounded",
      text = {
        top = title,
        top_align = "center",
        bottom = "rerun (r) | close (q) | save (s)",
        bottom_align = "center",
      },
    },
    buf_options = {
      -- modifiable = false,
      -- readonly = true,
    },
  })
end

-- Execute shell command using vim.fn.system
---@param exec string | table { string }
local function sys(exec, debug)
  if type(exec) == "table" then
    exec = table.concat(exec, " && ")
  end
  if debug then
    vim.print("Executing: " .. exec)
  end
  vim.fn.system(exec)
end

local function inspect(node)
  vim.print(getmetatable(node))
end

return M ]]
