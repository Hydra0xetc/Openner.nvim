---@diagnostic disable: deprecated
local M = {}

--- Creates a floating window to display and select from a list of applications
---
--- This function creates a floating window that displays a sorted list of applications
--- with numeric indices. Users can select an application by pressing Enter on the
--- corresponding number.
---
---@param applications table A table of application objects with `name`, `activity`, and optional `command` fields
---@param window_config table Configuration for the floating window with fields:
---                          - `width` (number): Window width
---                          - `height` (number): Window height
---                          - `border` (string): Window border style
---                          - `title` (string): Window title
---                          - `title_pos` (string): Title position
---@param default_command table Default command parts to use if application doesn't specify its own command
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

--- Sets up keymaps for navigating the floating window
---
--- Available keymaps:
--- - `q` or `<Esc>`: Close the window
--- - `<CR>`: Select the current application
---
---@param buf integer Buffer handle to set keymaps on
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

--- Configures buffer options for the floating window
---
--- Sets the buffer to:
--- - `buftype = "nofile"`: Temporary buffer
--- - `bufhidden = "wipe"`: Auto-wipe when hidden
--- - `modifiable = false`: Read-only buffer
--- - `filetype = "openner"`: Custom filetype
---
---@param buf integer Buffer handle to configure
function M.setup_buffer_options(buf)
	-- Buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile") -- buffer for temporary purposes
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe") -- buffer will automatically wiped when its not used
	vim.api.nvim_buf_set_option(buf, "modifiable", false) -- buffer non modifiable
	vim.api.nvim_buf_set_option(buf, "filetype", "openner") -- filetype for the buffer
end

--- Manages cursor positioning within the floating window
---
--- Ensures the cursor always stays on the number part of the selection
--- by automatically repositioning it if it moves away.
---
---@param buf integer Buffer handle to attach autocmds to
---@param win integer Window handle for cursor management
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

--- Selects and launches the currently highlighted application
---
--- Reads the application data from buffer variables, constructs the appropriate
--- command using either the application-specific command or default command,
--- and launches the application as a job.
---
--- Displays notifications for:
--- - Success/failure of application launch
--- - Errors for invalid selections or missing data
---
---@usage Called automatically when pressing `<CR>` in the floating window
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

--- Creates a floating window for managing application activation states.
---
--- This function displays all applications, indicating their activation status,
--- and allows the user to toggle the status of selected applications.
---
---@param applications table A table of all application objects (from config.applications)
---@param window_config table Configuration for the floating window
function M.create_management_window(applications, window_config)
    -- Sort applications by name for consistent ordering
    local sorted_apps = {}
    for _, app in pairs(applications) do
        table.insert(sorted_apps, app)
    end
    table.sort(sorted_apps, function(a, b)
        return a.name < b.name
    end)

    local lines = {}
    for i, app in ipairs(sorted_apps) do
        local status_icon = app.activated and "✓" or "✗"
        table.insert(lines, string.format("[%s] %s", status_icon, app.name))
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = window_config.width
    local height = math.min(window_config.height, #lines)
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
        title = "Manage " .. window_config.title,
        title_pos = window_config.title_pos,
    })

    -- Setup keymaps for the management window
    local manage_keymaps = {
        { "n", "q", "<Cmd>close<CR>", { noremap = true, silent = true } },
        { "n", "<Esc>", "<Cmd>close<CR>", { noremap = true, silent = true } },
        { "n", require("openner").get_config().manage_toggle_key, "<Cmd>lua require('openner.window').toggle_selected_app_status()<CR>", { noremap = true, silent = true } },
    }

    for _, map in ipairs(manage_keymaps) do
        vim.api.nvim_buf_set_keymap(buf, map[1], map[2], map[3], map[4])
    end

    -- Use existing buffer options and cursor management
    M.setup_buffer_options(buf)
    M.setup_cursor_management(buf, win)

    -- Store applications data in buffer variables
    vim.api.nvim_buf_set_var(buf, "openner_sorted_apps", sorted_apps)
    vim.api.nvim_buf_set_var(buf, "openner_win_id", win)

    -- Set current window
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { 1, 1 })

    vim.api.nvim_exec_autocmds("User", { pattern = "OpennerManageOpened" })
end

--- Toggles the activation status of the app under the cursor in the management window.
function M.toggle_selected_app_status()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    local sorted_apps = vim.api.nvim_buf_get_var(buf, "openner_sorted_apps")
    local line_num = vim.api.nvim_win_get_cursor(win)[1]
    local app_entry = sorted_apps[line_num]

    if app_entry and app_entry.name then
        local new_status = require("openner").toggle_app_activation(app_entry.name)
        local status_icon = new_status and "✓" or "✗"

        -- Update the displayed line
        local new_line = string.format("[%s] %s", status_icon, app_entry.name)
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, line_num - 1, line_num, false, { new_line })
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
    end
end

return M
