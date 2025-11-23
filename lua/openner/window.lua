local M = {}

function M.create_floating_window(applications, window_config, default_command)
	-- Sort applications by name for consistent ordering
	table.sort(applications, function(a, b)
		return a.name < b.name
	end)

	local lines = {}
	for i, app in ipairs(applications) do
		table.insert(lines, string.format("[%d] %s", i, app.name))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = window_config.width
	local height = math.min(window_config.height, #lines) -- Don't exceed available lines
	local top = math.floor(((vim.o.lines - height) / 2) - 1)
	local left = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = top,
		col = left,
		style = "minimal",
		border = window_config.border,
		title = window_config.title,
		title_pos = window_config.title_pos,
	})

	M.setup_buffer_keymaps(buf)
	M.setup_buffer_options(buf)
	M.setup_buffer_highlights(buf)
	M.setup_cursor_management(buf, win)

	-- Store applications data in buffer variables
	vim.api.nvim_buf_set_var(buf, "openner_applications", applications)
	vim.api.nvim_buf_set_var(buf, "openner_win_id", win)
	vim.api.nvim_buf_set_var(buf, "openner_default_command", default_command)

	-- Set current window
	vim.api.nvim_set_current_win(win)

	-- Set initial cursor position to first number
	vim.api.nvim_win_set_cursor(win, { 1, 1 })

	-- Trigger autocommand
	vim.api.nvim_exec_autocmds("User", { pattern = "OpennerOpened" })
end

function M.setup_buffer_keymaps(buf)
	local keymaps = {
		{ "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true } },
		{ "n", "<Esc>", "<Cmd>close<CR>", { noremap = true, silent = true } },
		{ "n", "<CR>", "<Cmd>lua require('openner').select_application()<CR>", { noremap = true, silent = true } },
	}

	for _, map in ipairs(keymaps) do
		vim.api.nvim_buf_set_keymap(buf, map[1], map[2], map[3], map[4])
	end
end

function M.setup_buffer_options(buf)
	-- Buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "openner")
end

function M.setup_buffer_highlights(buf)
	-- Syntax highlighting
	vim.api.nvim_buf_add_highlight(buf, -1, "Number", 0, 0, 2)
end

function M.setup_cursor_management(buf, win)
	-- Set cursor to always be on the number part
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		buffer = buf,
		callback = function()
			local cursor_pos = vim.api.nvim_win_get_cursor(win)

			-- If cursor is not on the number part, move it to the number
			local current_col = cursor_pos[2]
			if current_col < 1 or current_col > 1 then -- cursor pos always in number 1
				vim.api.nvim_win_set_cursor(win, { cursor_pos[1], 1 })
			end
		end,
	})
end

function M.select_application()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	-- Check if buffer has applications data
	local success, applications = pcall(vim.api.nvim_buf_get_var, buf, "openner_applications")
	if not success then
		vim.notify("No applications data found", vim.log.levels.ERROR)
		return
	end

	local success_default, default_command = pcall(vim.api.nvim_buf_get_var, buf, "openner_default_command")
	if not success_default then
		vim.notify("No default command found", vim.log.levels.ERROR)
		return
	end

	local line_num = vim.api.nvim_win_get_cursor(win)[1]
	local line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]

	if not line then
		vim.notify("Invalid line", vim.log.levels.ERROR)
		return
	end

	local index = tonumber(string.match(line, "%[(%d+)%]"))
	if index and applications[index] then
		local app = applications[index]
		local command_parts = app.command or default_command
		local command_to_run = table.concat(command_parts, " ") .. " " .. vim.fn.shellescape(app.activity)

		vim.notify("Opening: " .. app.name, vim.log.levels.INFO)

		-- Execute the application
		local job_opts = {
			on_exit = function(_, exit_code)
				if exit_code == 0 then
					vim.notify("Successfully opened: " .. app.name, vim.log.levels.INFO)
				else
					vim.notify("Failed to open: " .. app.name, vim.log.levels.ERROR)
				end
			end,
		}

		vim.fn.jobstart(command_to_run, job_opts)
		vim.api.nvim_win_close(win, true)
	else
		vim.notify("Invalid selection", vim.log.levels.ERROR)
	end
end

return M
