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
    (#eq? @_func_name "%s"))
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
---@param name string
function M.get_test_line(buf, name)
  u.debug("===============")
  local query_str = go_test_func_query_str:format(name)
  local root, query = M.parse_query(buf, query_str)
  if not root or not query then
    return
  end

  for id, node in query:iter_captures(root, buf) do
    local capture = query.captures[id]
    u.debug(id)
    u.debug(capture)

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

      if func_name == name then
        -- treesitter uses c-style indexing...
        return srow + 1
      end
    end
  end
end

---@param buf number
function M.get_test_func_at_cursor(buf)
  local node = tsu.get_node_at_cursor()

  while node do
    if node:type() == "function_declaration" then
      break
    end
    node = node:parent()
  end

  if not node then
    return
  end

  local func = vim.treesitter.get_node_text(node:named_child(0), buf)
  if func:sub(1, 4) == "Test" then
    return func
  end
end

return M
