-- One-shot prompt -> text backends, shared by genja-commit (<M-g>) and genja-ask.
-- Two kinds, one interface (`available()`, `run(prompt, opts, on_done)`):
--   cli   the prompt on stdin, the answer on stdout (npm .cmd shims cap the command line at 8191 chars)
--   http  an OpenAI-compatible chat completions end point through curl (ollama, LM Studio, OpenRouter, ...)
-- No streaming, no sessions; genja-ask's claude-p keeps its own backend for sessions.

local SRC = 'genja-util/llm.lua: '

local M = {}

---@class genja-util.llm.RunOpts
---@field cwd? string
---@field timeout? integer seconds; nil: no limit
---@field model? string overrides the backend's model

---@alias genja-util.llm.OnDone fun(err: string|nil, text?: string)

---@class genja-util.llm.Backend
---@field name string
---@field kind 'cli'|'http'
---@field available fun(self: genja-util.llm.Backend): boolean
---@field run fun(self: genja-util.llm.Backend, prompt: string, opts: genja-util.llm.RunOpts, on_done: genja-util.llm.OnDone): vim.SystemObj|nil

---@class genja-util.llm.CliSpec
---@field kind? 'cli'
---@field exe string executable, looked up with exepath()
---@field args? fun(opts: genja-util.llm.RunOpts, exe: string): string[] arguments after the executable

---@class genja-util.llm.HttpSpec
---@field kind? 'http'
---@field end_point string chat completions URL
---@field model string
---@field api_key? string|fun(): string|nil nil: no Authorization header
---@field body? table extra request fields (temperature, max_tokens, ...)

---Settings of a named backend; every field is optional.
---@class genja-util.llm.Settings
---@field model? string
---@field effort? string claude
---@field role? string aichat: used when `aichat --list-roles` has it
---@field instruction? string gemini: the -p text, appended to stdin
---@field end_point? string ollama
---@field api_key? string|fun(): string|nil ollama behind a proxy
---@field body? table ollama: extra request fields

M.OLLAMA_END_POINT = 'http://localhost:11434/v1/chat/completions'
M.OLLAMA_MODEL = 'qwen3.5:0.8b'

---Run `cmd` with `stdin`; `on_done` gets an error or stdout, on the main loop.
---@param cmd string[]
---@param stdin string
---@param opts genja-util.llm.RunOpts
---@param on_done genja-util.llm.OnDone
---@return vim.SystemObj
function M.exec(cmd, stdin, opts, on_done)
    local timeout = nil
    if opts.timeout then
        timeout = opts.timeout * 1000
    end
    return vim.system(cmd, { stdin = stdin, text = true, cwd = opts.cwd, timeout = timeout }, vim.schedule_wrap(function(res)
        if res.code == 124 then -- vim.system's timeout code
            on_done(('timed out after %d s'):format(opts.timeout))
            return
        end
        if res.code ~= 0 then
            local out = vim.trim((res.stderr or '') .. '\n' .. (res.stdout or ''))
            on_done(out .. ' (exit ' .. res.code .. ')')
            return
        end
        on_done(nil, res.stdout or '')
    end))
end

---A backend that runs a CLI with the prompt on stdin.
---@param name string
---@param spec genja-util.llm.CliSpec
---@return genja-util.llm.Backend
function M.cli(name, spec)
    return {
        name = name,
        kind = 'cli',
        available = function()
            return vim.fn.exepath(spec.exe) ~= ''
        end,
        run = function(_, prompt, opts, on_done)
            local exe = vim.fn.exepath(spec.exe) -- full path: finds .cmd shims on Windows
            if exe == '' then
                on_done(spec.exe .. ' is not on PATH')
                return nil
            end
            local cmd = { exe }
            if spec.args then
                vim.list_extend(cmd, spec.args(opts, exe))
            end
            return M.exec(cmd, prompt, opts, on_done)
        end,
    }
end

---Answer text from a chat completions response; thinking models may wrap their reasoning in <think>.
---@param stdout string
---@return string|nil err
---@return string|nil text
local function parse_chat(stdout)
    local ok, data = pcall(vim.json.decode, stdout)
    if not ok or type(data) ~= 'table' then
        return 'not JSON: ' .. stdout:sub(1, 200), nil
    end
    if type(data.error) == 'table' then
        return tostring(data.error.message), nil
    end
    local choice = type(data.choices) == 'table' and data.choices[1] or nil
    local content = choice and choice.message and choice.message.content
    if type(content) ~= 'string' then
        return 'no answer in the response', nil
    end
    content = content:gsub('^%s*<think>.-</think>', '')
    return nil, content
end

---A backend that posts the prompt to an OpenAI-compatible chat completions end point.
---@param name string
---@param spec genja-util.llm.HttpSpec
---@return genja-util.llm.Backend
function M.http(name, spec)
    return {
        name = name,
        kind = 'http',
        available = function()
            return vim.fn.executable('curl') == 1
        end,
        run = function(_, prompt, opts, on_done)
            local body = vim.tbl_extend('force', spec.body or {}, {
                model = opts.model or spec.model,
                messages = { { role = 'user', content = prompt } },
                stream = false,
            })
            -- the body goes on stdin, like the CLIs' prompts
            local cmd = {
                'curl', '-sS', '--fail-with-body', '-X', 'POST', spec.end_point,
                '-H', 'Content-Type: application/json', '--data-binary', '@-',
            }
            local key = spec.api_key
            if type(key) == 'function' then
                key = key()
            end
            if key then
                vim.list_extend(cmd, { '-H', 'Authorization: Bearer ' .. key })
            end
            if opts.timeout then
                vim.list_extend(cmd, { '--max-time', tostring(opts.timeout) })
            end
            return M.exec(cmd, vim.json.encode(body), opts, function(err, stdout)
                if err then
                    -- --fail-with-body: the server's error JSON is in the message
                    on_done(err)
                    return
                end
                local parse_err, text = parse_chat(stdout or '')
                on_done(parse_err, text)
            end)
        end,
    }
end

---`args`, plus `flag value` when value is set.
---@param args string[]
---@param flag string
---@param value string|nil
---@return string[]
local function with(args, flag, value)
    if value then
        vim.list_extend(args, { flag, value })
    end
    return args
end

---claude -p without tools: the answer comes from stdin only.
---@param s genja-util.llm.Settings
---@return genja-util.llm.Backend
function M.claude(s)
    return M.cli('claude', {
        exe = 'claude',
        args = function(opts)
            local args = with({ '-p', '--tools', '' }, '--model', opts.model or s.model)
            return with(args, '--effort', s.effort)
        end,
    })
end

---GitHub Copilot CLI (needs a Copilot plan). The prompt is piped, so no -p: copilot ignores
---stdin when -p is given. -s: answer only; --no-ask-user: never wait. No --allow-* flags:
---tools needing permission are refused.
---@param s genja-util.llm.Settings
---@return genja-util.llm.Backend
function M.copilot(s)
    return M.cli('copilot', {
        exe = 'copilot',
        args = function(opts)
            return with({ '-s', '--no-ask-user' }, '--model', opts.model or s.model)
        end,
    })
end

---gemini: the -p text is appended to stdin; -o text: plain answer.
---@param s genja-util.llm.Settings
---@return genja-util.llm.Backend
function M.gemini(s)
    local instruction = s.instruction or 'Follow the instructions above.'
    return M.cli('gemini', {
        exe = 'gemini',
        args = function(opts)
            return with({ '-p', instruction, '-o', 'text' }, '-m', opts.model or s.model)
        end,
    })
end

---aichat -S (no streaming); its role only when `aichat --list-roles` has it.
---@param s genja-util.llm.Settings
---@return genja-util.llm.Backend
function M.aichat(s)
    return M.cli('aichat', {
        exe = 'aichat',
        args = function(opts, exe)
            local args = with({ '-S' }, '-m', opts.model or s.model)
            if s.role then
                local roles = vim.system({ exe, '--list-roles' }, { text = true }):wait()
                local list = vim.split(roles.stdout or '', '\n', { trimempty = true })
                if roles.code == 0 and vim.list_contains(vim.tbl_map(vim.trim, list), s.role) then
                    vim.list_extend(args, { '-r', s.role })
                end
            end
            return args
        end,
    })
end

---ollama through its OpenAI-compatible end point; local by default, no key.
---@param s genja-util.llm.Settings
---@return genja-util.llm.Backend
function M.ollama(s)
    return M.http('ollama', {
        end_point = s.end_point or M.OLLAMA_END_POINT,
        model = s.model or M.OLLAMA_MODEL,
        api_key = s.api_key,
        body = s.body,
    })
end

---A backend by name: one of the built-in ones, or a custom spec (kind 'cli' or 'http').
---@param name string
---@param settings? genja-util.llm.Settings
---@param custom? genja-util.llm.CliSpec|genja-util.llm.HttpSpec
---@return genja-util.llm.Backend|nil
function M.named(name, settings, custom)
    settings = settings or {}
    if custom then
        if custom.kind == 'http' or custom.end_point then
            return M.http(name, custom --[[@as genja-util.llm.HttpSpec]])
        end
        return M.cli(name, custom --[[@as genja-util.llm.CliSpec]])
    end
    if name == 'claude' then
        return M.claude(settings)
    elseif name == 'copilot' then
        return M.copilot(settings)
    elseif name == 'gemini' then
        return M.gemini(settings)
    elseif name == 'aichat' then
        return M.aichat(settings)
    elseif name == 'ollama' then
        return M.ollama(settings)
    end
    vim.notify(SRC .. 'unknown backend ' .. name, vim.log.levels.WARN)
    return nil
end

return M
