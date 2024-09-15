local diag_me = 123

local ns = vim.api.nvim_create_namespace("go-tools-test")
vim.diagnostic.set(ns, 0, {
  {
    lnum = 0,
    col = 6,
    end_col = 13,
    severity = vim.diagnostic.severity.ERROR,
    message = "FAIL",
    -- source = "go-test",
    float = {
      header = "HEADERAAA",
      ---@param diag vim.Diagnostic
      format = function(diag)
        return "this is the text"
      end,
    },
  },
  --[[ {
    lnum = 0,
    col = 15,
    end_col = 30,
    severity = vim.diagnostic.severity.WARN,
    message = "warning",
  }, ]]
})

print(diag_me)
