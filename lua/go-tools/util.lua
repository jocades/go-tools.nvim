local M = {}

---@param msg string
---@param title? string
function M.err(msg, title)
  vim.notify(msg, vim.log.levels.ERROR, { title = title or "go-tools" })
end

---@param msg string
---@param title? string
function M.warn(msg, title)
  vim.notify(msg, vim.log.levels.WARN, { title = title or "go-tools" })
end

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

---@vararg table
function M.merge(...)
  return vim.tbl_deep_extend("force", ...)
end

---@param ls? string|string[]
---@return string
function M.to_csv(ls)
  return type(ls) == "table" and table.concat(ls, ",") or ls or "" ---@diagnostic disable-line: return-type-mismatch
end

return M
