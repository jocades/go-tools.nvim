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

function M.ins(what, noti)
  if noti then
    vim.notify(vim.inspect(what))
  else
    print(vim.inspect(what))
  end
end

function M.dbg(what, noti)
  if vim.env.DEBUG == "go-tools" then
    M.ins(what, noti)
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

return M
