---@param args string[]
---@param opts? { flag_prefix?: string }
local function Command(args, opts)
  opts = opts or {}

  ---@class Command
  local cmd = {
    ---@type table<string,string>
    _flags = {},
  }

  local function make_key(flag)
    return (opts.flag_prefix or "-") .. flag
  end

  ---@param key string
  ---@param val string
  function cmd:set(key, val)
    self._flags[key] = val
  end

  ---@param val string
  function cmd:arg(val)
    table.insert(args, val)
  end

  ---@param key string
  ---@param val string
  function cmd:flag(key, val)
    if not key or not val then
      return
    end
    self._flags[make_key(key)] = val
  end

  ---@param flag string
  function cmd:get(flag)
    return self._flags[make_key(flag)]
  end

  ---@param flag string
  function cmd:has(flag)
    return self._flags[make_key(flag)] ~= nil
  end

  ---@param arg? string
  function cmd:build(arg)
    for k, v in pairs(self._flags) do
      table.insert(args, k)
      table.insert(args, v)
    end
    if arg then
      table.insert(args, arg)
    end
    return args
  end

  ---@param callback fun(p: vim.SystemCompleted)
  function cmd:spawn(callback)
    return vim.system(self:build(), { text = true }, callback)
  end

  return cmd
end

return Command
