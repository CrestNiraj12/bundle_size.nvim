# bundle_size.nvim

Display the current buffer size (raw, gzip, brotli) in your statusline.

This plugin computes:

- **raw**: byte length of the current buffer text
- **gz**: gzip-compressed byte length (requires `gzip` on your `$PATH`)
- **br**: brotli-compressed byte length (requires `brotli` on your `$PATH`)

The value is exposed via `require("bundle_size").status()` so you can show it in
lualine, heirline, a custom statusline, etc.

## Requirements

- Neovim **0.10+** (uses `vim.system` and `vim.uv`)
- Optional: `gzip` executable for gzip size (if missing, `gz ?` is shown)
- Optional: `brotli` executable for brotli size (if missing, `br ?` is shown)

## Installation

### lazy.nvim

```lua
{
  "niraj-shrestha/bundle_size.nvim",
  opts = {
    -- your config here (see Options)
  },
}
```

### packer.nvim

```lua
use({
  "niraj-shrestha/bundle_size.nvim",
  config = function()
    require("bundle_size").setup()
  end,
})
```

## Pros

- **Instant feedback**: see raw/gzip/brotli sizes as you edit.
- **Statusline-friendly**: a single `status()` function works with any
  statusline plugin.
- **Low overhead**: debounced updates + throttled redraw to reduce flicker.
- **Safe on large files**: skips compression work past a size threshold.
- **Async compression**: uses `vim.system()` to avoid blocking the UI.
- **Configurable**: toggle metrics, separator, filetypes, and brotli quality.

## Usage

1. Call `setup()` once.
2. Add the status function to your statusline.

### Minimal setup

```lua
require("bundle_size").setup()
```

### Add to statusline

#### lualine

```lua
require("lualine").setup({
  sections = {
    lualine_c = {
      "filename",
      function()
        return require("bundle_size").status()
      end,
    },
  },
})
```

#### vim.o.statusline

```lua
require("bundle_size").setup()

vim.o.statusline = table.concat({
  "%f",
  "%=",
  "%{v:lua.require('bundle_size').status()}",
}, " ")
```

## Options

`setup()` accepts an options table. Defaults:

```lua
{
  delay_ms = 200,
  max_file_size_kb = 1024,
  enabled_filetypes = {
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
    css = true,
    scss = true,
    html = true,
    json = true,
    lua = true,
  },
}
```

### `delay_ms`

Debounce delay for recalculating sizes on `TextChanged`/`TextChangedI`.

### `max_file_size_kb`

If the raw buffer size exceeds this threshold, the plugin still shows `raw` but
marks it as too large and skips meaningful gzip computation output.

### `enabled_filetypes`

A map of filetype -> boolean. If non-empty, only filetypes set to `true` are
processed.

## How it works

- Refreshes on `BufEnter` and `BufWritePost`
- Debounced refresh on `TextChanged` and `TextChangedI`
- Uses `gzip -c` to compute compressed output size asynchronously
- Throttles statusline redraw to reduce flicker

## License

MIT

