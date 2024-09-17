# go-tools.nvim

A set of tools for Go development in Neovim, written in Lua.

- Dependencies:
  - Treesitter parser for Go.
  - Go itself (kind of obvious).

## 1. Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim) package manager.

```lua
  {
    "jocades/go-tools.nvim",
    ft = "go",
    opts = {},
  },
```

<details>
  <summary>
    Default options.
  </summary>

```lua
  {
    "jocades/go-tools.nvim",
    ft = "go",
    ---@module "go-tools"
    ---@type gotools.Opts
    opts = {
      gotags = {
        tags = "json",
        transform = "camelcase",
        template = nil,
      },
      gotest = {
        split = "bottom",
      },
    },
  },
```

</details>

## 2. Features

### 2.1 gotags

Modify/update field tags in structs with [gomodifytags](https://github.com/fatih/gomodifytags). **Only** the selected struct or fields will be replaced (not the entire buffer).<br>
Place the cursor anywhere in the struct or select the fields to modify, then run the command.<br>

- Commands:

  ```vim
  :GoTagsAdd [OPTIONS]
  :GoTagsRemove [OPTIONS]
  :GoTagsClear
  ```

  Options are in the form of `key=value` pairs, separated by a space `:GoTagsAdd tags=json,xml transform=camelcase`<br>

- Lua API:

  ```lua
  local go = require("go-tools")

  go.tags.add()
  go.tags.remove()
  go.tags.clear()
  ```

### 2.2 gotest

Run tests for the current file, function or package with the `go test` command.<br>
Display nice diagnostics in the buffer, navigate between them with your default LSP keybindings and show the output for a given test or suite.

- Commands:

  ```vim
  :GoTest
  :GoTestFunc
  ```

- Lua API:

  ```lua
  local go = require("go-tools")

  go.test.run()
  go.test.run_func()
  ```
