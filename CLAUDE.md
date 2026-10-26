# genja-util.nvim

Helpers shared by the plug-wip plugins. Loaded as a lazy `dependencies` entry of
each spec that uses it (`lua/lazyp/new/genja-*.lua`); tests prepend it to the rtp.

How this file is kept: one heading per feature, one bullet per decision.
Unmarked bullets were stated by jaro. `(inferred)` marks Claude's reading of the
code or history: confirm or delete. `Hint:` is a working note for Claude.

## Layout

- `lua/genja-util/float.lua`: `scratch(lines)`, `open(buf, opts)` (centred rounded float), `close(win)`.
- `lua/genja-util/text.lua`: `uuid()` (v4, for `claude --session-id`), `fenced(code, lang)`, `visual_lines()`.

## Decisions

- Holds only code used by two or more plug-wip plugins; no `setup()`, no options.
- Must not require `genja.*` or any other plugin.
