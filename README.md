# genja-util.nvim

Small helpers shared by the genja Neovim plugins (genja-ask, genja-claudefterm,
genja-commit, genja-finder).

- `require('genja-util.float')`: `scratch(lines?)`, `open(buf, { width, height, title?, enter?, zindex?, up?, left? })`, `close(win)`.
- `require('genja-util.text')`: `uuid()`, `fenced(code, lang)`, `visual_lines()`.
- `require('genja-util.llm')`: one-shot prompt -> text backends (claude, copilot, gemini, aichat CLIs; ollama or any OpenAI-compatible HTTP end point).

## Install

A dependency of the other genja plugins; list it in their `dependencies` and
lazy.nvim installs it:

```lua
{ 'tox2ik/genja-foo.nvim', dependencies = { 'tox2ik/genja-util.nvim' } }
```

No `setup()`, no options.

## License

MIT
