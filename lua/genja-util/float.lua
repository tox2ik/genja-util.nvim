-- Centred floating windows for the plug-wip popups (ask, commit, finder).
local M = {}

---Scratch buffer, wiped when hidden.
---@param lines? string[]
---@return integer buf
function M.scratch(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = 'wipe'
	if lines then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end
	return buf
end

---@class genja-util.FloatOpts
---@field width integer text width, without the border
---@field height integer text rows, without the border; at least 1
---@field title? string padded with a space on each side
---@field enter? boolean focus the window (default true)
---@field zindex? integer
---@field up? integer rows above the centre
---@field left? integer columns left of the centre

---Open `buf` in a rounded, minimal float in the middle of the editor.
---@param buf integer
---@param o genja-util.FloatOpts
---@return integer win
function M.open(buf, o)
	local height = math.max(o.height, 1)
	---@type vim.api.keyset.win_config
	local cfg = {
		relative = 'editor',
		style = 'minimal',
		border = 'rounded',
		zindex = o.zindex,
		width = o.width,
		height = height,
		row = math.max(math.floor((vim.o.lines - height) / 2) - (o.up or 0), 0),
		col = math.max(math.floor((vim.o.columns - o.width) / 2) - (o.left or 0), 0),
	}
	if o.title then
		cfg.title = ' ' .. o.title .. ' '
		cfg.title_pos = 'center'
	end
	return vim.api.nvim_open_win(buf, o.enter ~= false, cfg)
end

---Close `win`; leave insert mode first when it has focus.
---@param win integer
function M.close(win)
	if vim.api.nvim_get_current_win() == win then
		vim.cmd.stopinsert()
	end
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

return M
