local M = {}

local function get_plugin_path()
	local lazypath = vim.fn.stdpath("data") .. "/lazy/openner/"
	if vim.fn.isdirectory(lazypath) == 1 then
		return lazypath
	end
end

function M.open()
	local applications = {}
	local path = get_plugin_path()

	-- validate path exists
	if vim.fn.isdirectory(path) == 0 then
		return
	end

	local files = vim.fn.readdir(path)
	for _, file in ipairs(files) do
		if file ~= "." and file ~= ".." then
			table.insert(applications, {
				name = file,
				path = path .. file,
			})
		end
	end

	if #applications == 0 then
		vim.notify("No applications found in " .. path, vim.log.levels.WARN)
		return
	end

	local lines = {}
	for i, app in ipairs(applications) do
		table.insert(lines, string.format("%d: %s", i, app.name))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 50
	local height = #lines
	local top = math.floor(((vim.o.lines - height) / 2) - 1)
	local left = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = top,
		col = left,
		style = "minimal",
		border = "rounded",
		title = "Applications",
		title_pos = "center",
	})

	-- Key mappings
	local keymaps = {
		{ "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true } },
		{ "n", "<Esc>", "<Cmd>close<CR>", { noremap = true, silent = true } },
		{ "n", "<CR>", "<Cmd>lua require('Openner').select_application()<CR>", { noremap = true, silent = true } },
	}

	for _, map in ipairs(keymaps) do
		vim.api.nvim_buf_set_keymap(buf, map[1], map[2], map[3], map[4])
	end

	-- Buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "opener")

	-- Store applications data in buffer variables
	vim.api.nvim_buf_set_var(buf, "opener_applications", applications)
	vim.api.nvim_buf_set_var(buf, "opener_win_id", win)

	-- Syntax highlighting
	vim.api.nvim_buf_add_highlight(buf, -1, "Number", 0, 0, 2)

	-- Set current window
	vim.api.nvim_set_current_win(win)

	-- Trigger autocommand
	vim.api.nvim_exec_autocmds("User", { pattern = "OpenerOpened" })
end

-- Function to handle application selection
function M.select_application()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	-- Check if buffer has applications data
	local success, applications = pcall(vim.api.nvim_buf_get_var, buf, "opener_applications")
	if not success then
		vim.notify("No applications data found", vim.log.levels.ERROR)
		return
	end

	local line_num = vim.api.nvim_win_get_cursor(win)[1]
	local line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]

	if not line then
		vim.notify("Invalid line", vim.log.levels.ERROR)
		return
	end

	local index = tonumber(string.match(line, "(%d+):"))
	if index and applications[index] then
		local app = applications[index]

		-- Validate if file exists and is executable
		if vim.fn.executable(app.path) == 0 then
			vim.notify("Application not executable: " .. app.path, vim.log.levels.ERROR)
			return
		end

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

		vim.fn.jobstart("bash " .. vim.fn.shellescape(app.path), job_opts)
		vim.api.nvim_win_close(win, true)
	else
		vim.notify("Invalid selection", vim.log.levels.ERROR)
	end
end

return M
