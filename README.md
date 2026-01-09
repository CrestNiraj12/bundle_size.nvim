# compress-size.nvim

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim Version](https://img.shields.io/badge/Neovim-0.10+-blue.svg)](https://neovim.io/)

A Neovim plugin to display the current buffer size (raw, gzip, brotli) in your statusline.

This plugin computes and displays:
- **raw**: Byte length of the current buffer text
- **gz**: Gzip-compressed byte length (requires `gzip` on PATH)
- **br**: Brotli-compressed byte length (requires `brotli` on PATH)

## Requirements

- **Neovim 0.10+** (uses `vim.system` and `vim.uv`)
- Optional: `gzip` executable for gzip compression size
- Optional: `brotli` executable for brotli compression size

## Installation

### lazy.nvim

```lua
{
  "CrestNiraj12/compress-size.nvim",
  opts = {
    -- your config here (see Options)
  },
}
```

### packer.nvim

```lua
use({
  "CrestNiraj12/compress-size.nvim",
  config = function()
    require("compress_size").setup()
  end,
})
```

## Usage

1. Call `require("compress_size").setup()` in your init.lua.
2. Add the status function to your statusline.

### Minimal Setup

```lua
require("compress_size").setup()
```

### Integrate with Statusline

#### lualine

```lua
require("lualine").setup({
  sections = {
    lualine_c = {
      "filename",
      function()
        return require("compress_size").status()
      end,
    },
  },
})
```

#### Custom Statusline

```lua
require("compress_size").setup()

vim.o.statusline = table.concat({
  "%f",
  "%=",
  "%{v:lua.require('compress_size').status()}",
}, " ")
```

## Options

Pass options to `setup()`. Defaults:

```lua
{
  enabled = true,
  show = { raw = true, gzip = true, brotli = true },
  delay_ms = 200,
  brotli_quality = 11,
  max_file_size_kb = 1024,
  separator = "|",
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

### Option Details

- `enabled` (boolean): Enable/disable the plugin.
- `show` (table): Which sizes to display (raw, gzip, brotli).
- `delay_ms` (number): Debounce delay for updates on text changes.
- `brotli_quality` (number): Compression quality for brotli (1-11).
- `max_file_size_kb` (number): Max buffer size in KB before skipping compression.
- `separator` (string): Separator between metrics in statusline.
- `enabled_filetypes` (table): Map of filetype -> boolean for which files to process.

## Commands

- `:CompressSizeRefresh` — Force recompute sizes and show "Refreshing…" indicator.
- `:CompressSizeToggle` — Toggle the plugin on/off. When off, statusline shows nothing.

### Silent Toggle

To disable notifications when toggling the plugin, set:

```lua
vim.g.compress_size_silent_toggle = true
```

## How It Works

- Refreshes on `BufEnter` and `BufWritePost`.
- Debounced updates on `TextChanged` and `TextChangedI`.
- Asynchronous compression using `vim.system()` to avoid blocking.
- Skips compression for files larger than `max_file_size_kb`.
- Throttled statusline redraws to minimize flicker.
- Buffer text reading is synchronous but kept lightweight.

## License

MIT

