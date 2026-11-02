# genja-util.nvim

Helpers shared by the plug-wip plugins. Loaded as a lazy `dependencies` entry of
each spec that uses it (`lua/lazyp/new/genja-*.lua`); tests prepend it to the rtp.

How this file is kept: one heading per feature, one bullet per decision.
Unmarked bullets were stated by jaro. `(inferred)` marks Claude's reading of the
code or history: confirm or delete. `Hint:` is a working note for Claude.

## Layout

- `lua/genja-util/float.lua`: `scratch(lines)`, `open(buf, opts)` (centred rounded float), `close(win)`.
- `lua/genja-util/text.lua`: `uuid()` (v4, for `claude --session-id`), `fenced(code, lang)`, `visual_lines()`.
- `lua/genja-util/llm.lua`: one-shot prompt -> text backends for genja-commit and genja-ask: `cli(name, spec)` (prompt on stdin), `http(name, spec)` (OpenAI-compatible chat completions via curl), built-ins `claude`, `copilot`, `gemini`, `aichat`, `ollama`, and `named(name, settings, custom)`; `exec()` runs a command with stdin and a timeout.
- `llm.lua` takes settings per call (no options of its own); the API key is a string or a function, so the config can pass its secrets getter.

## Decisions

- Holds only code used by two or more plug-wip plugins; no `setup()`, no options.
- Must not require `genja.*` or any other plugin.
