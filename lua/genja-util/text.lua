-- Text helpers for the plug-wip plugins (ask, claudefterm).
local M = {}

---Random version 4 UUID, for `claude --session-id`.
---@return string
function M.uuid()
	local b = { assert(vim.uv.random(16)):byte(1, 16) }
	b[7] = b[7] % 16 + 0x40 -- version 4
	b[9] = b[9] % 64 + 0x80 -- RFC 4122 variant
	local hex = ('%02x'):rep(16):format(unpack(b))
	return ('%s-%s-%s-%s-%s'):format(hex:sub(1, 8), hex:sub(9, 12), hex:sub(13, 16), hex:sub(17, 20), hex:sub(21))
end

---`code` in a markdown fence longer than any backtick run inside it, so it can't close early.
---@param code string
---@param lang string info string, e.g. the filetype
---@return string
function M.fenced(code, lang)
	local ticks = '```'
	for run in code:gmatch('`+') do
		if #run >= #ticks then
			ticks = ('`'):rep(#run + 1)
		end
	end
	return ticks .. lang .. '\n' .. code .. '\n' .. ticks
end

---Lines of the current visual selection, first <= last; leaves visual mode.
---@return integer first, integer last
function M.visual_lines()
	local first, last = vim.fn.line('v'), vim.fn.line('.')
	vim.api.nvim_feedkeys(vim.keycode('<Esc>'), 'n', false)
	return math.min(first, last), math.max(first, last)
end

return M
