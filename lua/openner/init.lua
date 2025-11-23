local M = {}
local window = require("openner.window")

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
		Deepseek = {
			name = "DeepSeek",
			activity = "com.deepseek.chat/.MainActivity",
			activated = true,
		},
		Firefox = {
			name = "FireFox",
			activity = "org.mozilla.firefox/.App",
			activated = true,
		},
		Instagram = {
			name = "Instagram",
			activity = "com.instagram.android/.activity.MainTabActivity",
			activated = true,
		},
		Youtube = {
			name = "YouTube",
			activity = "com.google.android.youtube/.HomeActivity",
			activated = true,
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
		config = vim.tbl_deep_extend("force", config, user_config)
	end

	-- Set activated to true by default for all applications
	for _, app_config in pairs(config.applications) do
		if app_config.activated == nil then
			app_config.activated = true
		end
	end

	-- validate config
	M.validate_config()
end

function M.open()
	local active_applications = {}
	for name, app_config in pairs(config.applications) do
		if app_config.activated then
			app_config.name = app_config.name or name
			table.insert(active_applications, app_config)
		end
	end

	if #active_applications == 0 then
		vim.notify("No active applications found in config", vim.log.levels.WARN)
		return
	end

	window.create_floating_window(active_applications, config.window, config.default_command)
end

function M.select_application()
	window.select_application()
end

function M.open_single_app(app_to_find)
	local app_config
	local app_key_found

	for key, app in pairs(config.applications) do
		if key == app_to_find or (app.name and app.name == app_to_find) then
			app_config = app
			app_key_found = key
			break
		end
	end

	if not app_config then
		vim.notify("Application not found: " .. app_to_find, vim.log.levels.ERROR)
		return
	end

	local app_name = app_config.name or app_key_found

	if app_config.activated == false then
		vim.notify("Application is not active: " .. app_name, vim.log.levels.WARN)
		return
	end

	local command_parts = app_config.command or config.default_command
	local command_to_run = table.concat(command_parts, " ") .. " " .. vim.fn.shellescape(app_config.activity)

	vim.notify("Opening: " .. app_name, vim.log.levels.INFO)

	local job_opts = {
		on_exit = function(_, exit_code)
			if exit_code == 0 then
				vim.notify("Successfully opened: " .. app_name, vim.log.levels.INFO)
			else
				vim.notify("Failed to open: " .. app_name, vim.log.levels.ERROR)
			end
		end,
	}

	vim.fn.jobstart(command_to_run, job_opts)
end

return M
