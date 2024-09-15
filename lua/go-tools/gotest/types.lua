---@meta

---@class gotest.Entry
---@field Time string
---@field Action string
---@field Package string
---@field Test? string
---@field Output? string
---@field Elapsed? number

---@class gotest.StartEntry : gotest.Entry
---@field Action "start"

---@class gotest.RunEntry : gotest.Entry
---@field Action "run"
---@field Test string

---@class gotest.OutputEntry : gotest.Entry
---@field Action "output"
---@field Test string
---@field Output string

---@class gotest.DoneEntry : gotest.OutputEntry
---@field Action "pass" | "fail"
---@field Test string
---@field Elapsed number

---@class gotest.PassEntry : gotest.DoneEntry
---@field Action "pass"

---@class gotest.FailEntry : gotest.DoneEntry
---@field Action "fail"
