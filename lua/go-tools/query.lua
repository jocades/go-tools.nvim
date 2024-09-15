local tsu = require("nvim-treesitter.ts_utils")
local u = require("go-tools.util")

local M = {}

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
    (%s))
]]
-- (#eq? @_func_name "%s"))

local go_struct_type_query_str = [[
  ((type_declaration
    (type_spec
      name: (type_identifier) @_struct_name
      type: (struct_type
        (field_declaration_list)))))
]]

---@param buf number
---@param query_str string
function M.parse_query(buf, query_str)
  local ft = vim.bo[buf].ft
  local lang = vim.treesitter.language.get_lang(ft)

  if not lang then
    u.err("No treesitter parser found for " .. ft)
    return
  end

  local root = vim.treesitter.get_parser(buf):parse()[1]:root()
  local query = vim.treesitter.query.parse(lang, query_str)

  return root, query
end

---@param buf number
---@param query_str string
---@param capture string
function M.get_nodes(buf, query_str, capture)
  local root, query = M.parse_query(buf, query_str)
  if not root or not query then
    return
  end

  ---@type TSNode[]
  local nodes = {}
  for id, node in query:iter_captures(root, buf) do
    if query.captures[id] == capture then
      table.insert(nodes, node)
    end
  end

  return nodes
end

---@param buf number
---@param query_str string
---@param capture string
function M.get_node(buf, query_str, capture)
  local nodes = M.get_nodes(buf, query_str, capture)
  return nodes and nodes[1]
end

---@param buf number
---@param name string
function M.get_test_line(buf, name)
  local capture = ('#eq? @_func_name "%s"'):format(name)
  local query_str = go_test_func_query_str:format(capture)
  local node = M.get_node(buf, query_str, "_func_name")
  if not node then
    return
  end
  local row, col, erow, ecol = node:range()
  local func_name = vim.treesitter.get_node_text(node, buf)
  u.title("get_test_line", true)
  u.dbg({
    func_name = func_name,
    row = row,
    col = col,
    erow = erow,
    ecol = ecol,
  })
  -- treesitter uses c-style indexing
  return row + 1
end

---@param buf number
function M.get_test_func_at_cursor(buf)
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
  local name = vim.treesitter.get_node_text(node, buf)
  if name:sub(1, 4) == "Test" then
    return name, node:range() + 1
  end
end

---@param buf number
function M.get_struct_at_cursor(buf)
  local node = tsu.get_node_at_cursor()

  while node do
    if node:type() == "type_declaration" then
      if node:named_child(0):child(1):type() == "struct_type" then
        local name = node:named_child(0):child(0)
        return name and vim.treesitter.get_node_text(name, buf)
      end
    end
    node = node:parent()
  end
end

---@param buf number
function M.get_test_func_nodes(buf)
  return M.get_nodes(
    buf,
    go_test_func_query_str:format('#match? @_func_name "^Test"'),
    "_func_name"
  )
end

---@param buf number
function M.get_pkg_name(buf)
  local pkg_node = M.get_node(
    buf,
    [[
      ((source_file
        (package_clause
          (package_identifier) @_pkg_name)))
    ]],
    "_pkg_name"
  )

  if not pkg_node then
    return
  end

  local pkg = vim.treesitter.get_node_text(pkg_node, buf)
  u.dbg(pkg)
end

return M
