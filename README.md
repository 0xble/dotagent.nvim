# dotagent.nvim

`dotagent.nvim` provides slash-prefixed completion for local agent commands and skills inside Neovim.

It is intentionally conservative by default. The plugin stays off in normal editing buffers unless you explicitly attach it or launch Neovim through an external-editor flow marked with `DOTAGENT_EDITOR_PROMPT=1`.

## Requirements

- Neovim 0.10+
- `saghen/blink.cmp`

## Release Status

The current recommended public tag is `v0.3.1`.

The plugin uses git tags for releases. There is no separate version file in the repo.

## Features

- Scans local command markdown files and skill directories
- Provides a Blink source for `/command` and `/skill` completion
- Uses distinct Dotagent menu icons by default: `⚡` for commands, `󰧑` for skills
- Auto-attaches only when the editor session is launched with `DOTAGENT_EDITOR_PROMPT=1`
- Supports manual `:DotagentAttach` and `:DotagentDetach`
- Includes `:DotagentRefresh`, `:DotagentBrowse`, and `:DotagentHealth`

## Install

Lazy example:

```lua
{
  "0xble/dotagent.nvim",
  config = function()
    require("dotagent").setup({
      sources = {
        {
          type = "commands",
          path = vim.fn.expand("~/dotfiles/dot_agent/commands"),
        },
        {
          type = "skills",
          path = vim.fn.expand("~/dotfiles/dot_agent/skills"),
        },
      },
    })
  end,
}
```

Blink setup:

```lua
{
  "saghen/blink.cmp",
  opts = function(_, opts)
    opts.sources = opts.sources or {}
    opts.sources.default = function()
      local sources = { "lsp", "path", "snippets" }
      if require("dotagent").is_buffer_enabled(0) then
        table.insert(sources, 1, "dotagent")
      elseif vim.bo.filetype ~= "" and vim.bo.filetype ~= "markdown" and vim.bo.filetype ~= "text" and vim.bo.filetype ~= "gitcommit" then
        table.insert(sources, "buffer")
      end
      return sources
    end

    opts.sources.providers = opts.sources.providers or {}
    opts.sources.providers.dotagent = require("dotagent.completion.blink").provider()
  end,
}
```

## Recommended Integration

The best integration is an external-editor flow where Claude Code or a Codex launcher opens Neovim for prompt composition.

By default the plugin uses `/`, which is the more common command prefix in editor and agent UIs.

Use one shared launcher for those flows:

```sh
#!/bin/sh
export DOTAGENT_EDITOR_PROMPT=1
exec nvim "$@"
```

Then point your agent surface at that launcher:

- Claude Code: configure its external editor, then use `Ctrl+G`
- Codex or an editor-backed wrapper like `ai`: set `EDITOR` to the same launcher

When Neovim starts with `DOTAGENT_EDITOR_PROMPT=1`, `dotagent.nvim` attaches only to the initial prompt buffer. Additional buffers opened later in that session stay unaffected.

## Default Behavior

Without `DOTAGENT_EDITOR_PROMPT=1`, the plugin does not auto-attach in regular buffers.

The fallback path is manual:

- `:DotagentAttach`
- `:DotagentDetach`

That keeps slash completion out of normal code editing by default.

## Commands

- `:DotagentAttach [bufnr]`
- `:DotagentDetach [bufnr]`
- `:DotagentRefresh`
- `:DotagentBrowse`
- `:DotagentHealth`

## Configuration

```lua
require("dotagent").setup({
  icons = {
    command = "⚡",
    skill = "󰧑",
  },
  activation = {
    mode = "contextual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    {
      type = "commands",
      path = vim.fn.expand("~/dotfiles/dot_agent/commands"),
    },
    {
      type = "skills",
      path = vim.fn.expand("~/dotfiles/dot_agent/skills"),
    },
    {
      type = "items",
      items = {
        {
          name = "ship",
          kind = "command",
          description = "Example Lua-defined item",
        },
      },
    },
  },
})
```

`icons` is optional. Override either kind if you want a different source-specific
menu icon, or set a value to `""` to fall back to Blink's normal kind icon for
that item kind.

If you want a different prefix, override it explicitly.

Brian's setup keeps `$`:

```lua
require("dotagent").setup({
  prefixes = { "$" },
  activation = {
    mode = "contextual",
    env_var = "DOTAGENT_EDITOR_PROMPT",
  },
  sources = {
    {
      type = "commands",
      path = vim.fn.expand("~/dotfiles/dot_agent/commands"),
    },
    {
      type = "skills",
      path = vim.fn.expand("~/dotfiles/dot_agent/skills"),
    },
  },
})
```

`activation.mode` values:

- `"contextual"`: attach only when launched with the editor prompt env marker
- `"manual"`: never auto-attach
- `"global"`: enable in every non-terminal buffer
