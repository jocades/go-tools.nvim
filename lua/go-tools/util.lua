local M = {}

function M.ins(what)
  vim.print(vim.inspect(what))
end

function M.dbg(what)
  if vim.env.DEBUG == "go-tools" then
    M.ins(what)
  end
end

function M.title(s, dbg)
  local title = ("==== %s ===="):format(s)
  if dbg then
    M.dbg(title)
  else
    vim.print(title)
  end
end

---Merge any number of tables recursively without modifying the original tables.
---@vararg table
---@return table # The extended table
function M.extend(...)
  return vim.tbl_deep_extend("force", ...)
end

---Merge two tables recursively, modifying the first table.
---@param t1 table
---@param t2 table
function M.merge(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" then
      t1[k] = M.extend(t1[k] or {}, v)
    else
      t1[k] = v
    end
  end
end

---@param ls? string|string[]
---@return string
function M.to_csv(ls)
  return type(ls) == "table" and table.concat(ls, ",") or ls or "" ---@diagnostic disable-line: return-type-mismatch
end

M.log = require("go-tools.log")("go-tools")

return M
