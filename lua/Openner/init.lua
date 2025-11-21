local M = {}

local config = {
	window = {
		width = 50,
		height = 10,
		border = "rounded",
		title = "Applications",
		title_pos = "center",
	},
	default_command = { "am", "start", "--user", "0", "-n" },
	applications = {
		{
			name = "DeepSeek",
			activity = "com.deepseek.chat/.MainActivity",
		},
		{
			name = "FireFox",
			activity = "org.mozilla.firefox/.App",
		},
		{
			name = "Instagram",
			activity = "com.instagram.android/.activity.MainTabActivity",
		},
		{
			name = "YouTube",
			activity = "com.google.android.youtube/.HomeActivity",
		},
	},
}

function M.validate_config()
	-- validate window dimensions
	if config.window.width <= 0 then
		vim.notify("Window width must be positive", vim.log.levels.WARN)
		config.window.width = 50
	end

	if config.window.height <= 0 then
		vim.notify("Window height must be positive", vim.log.levels.WARN)
		config.window.height = 10
	end

	-- validate border style
	local valid_borders = { "none", "rounded", "single", "double", "shadow", "solid" }
	local valid_border = false

	for _, border in ipairs(valid_borders) do
		if config.window.border == border then
			valid_border = true
			break
		end
	end

	if not valid_border then
		vim.notify("Invalid border style", vim.log.levels.WARN)
		config.window.border = "rounded"
	end
end

function M.setup(user_config)
	if user_config then
		-- Manually merge the applications table
		if user_config.applications then
			for _, app in ipairs(user_config.applications) do
				table.insert(config.applications, app)
			end
			user_config.applications = nil -- Prevent overwrite by tbl_deep_extend
		end
		config = vim.tbl_deep_extend("force", config, user_config)
	end

	-- validate config
	M.validate_config()
end

function M.open()
	local applications = config.applications

	if #applications == 0 then
		vim.notify("No applications found in config", vim.log.levels.WARN)
		return
	end

	local lines = {}
	for i, app in ipairs(applications) do
		table.insert(lines, string.format("%d: %s", i, app.name))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = config.window.width
	local height = math.min(config.window.height, #lines) -- Don't exceed available lines
	local top = math.floor(((vim.o.lines - height) / 2) - 1)
	local left = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = top,
		col = left,
		style = "minimal",
		border = config.window.border,
		title = config.window.title,
		title_pos = config.window.title_pos,
	})

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
		local command_parts = app.command or config.default_command
		local command_to_run = table.concat(command_parts, " ") .. " " .. app.activity

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
