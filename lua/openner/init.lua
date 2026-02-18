---@diagnostic disable: deprecated
local M = {}

APK_PATH = "/data/data/com.termux/files/usr/tmp/ActivityLister.apk"
APK_URL = "https://github.com/Hydra0xetc/Openner.nvim/releases/download/1.0.0/ActivityLister.apk"
PACKAGE = "com.activity.lister"

local config = {
    window = {
        width = 50,
        height = 10,
        border = "rounded"
    },
    default_command = { "am", "start", "--user", "0", "-n" },
    applications = {},
}

local function notify(msg, level)
    vim.notify("[Openner] " .. msg, level)
end

local function is_app_installed()
    local result = vim.fn.system("/system/bin/pm list packages " .. PACKAGE)
    return result:match(PACKAGE) ~= nil
end

local function do_open_installer()
    notify("Opening ActivityLister installer...", vim.log.levels.INFO)
    vim.fn.jobstart("termux-open " .. APK_PATH, {
        on_exit = function(_, _)
            notify("Installation done? Run :OpennerScan to continue.", vim.log.levels.WARN)
        end
    })
end

local function do_download()
    notify("Downloading ActivityLister.apk...", vim.log.levels.INFO)
    vim.fn.jobstart("wget -O " .. APK_PATH .. " " .. APK_URL, {
        on_exit = function(_, code)
            if code == 0 then
                notify("Download complete!", vim.log.levels.INFO)
                do_open_installer()
            else
                notify("Download failed! Check your internet connection.", vim.log.levels.ERROR)
            end
        end
    })
end

function M.setup(user_config)
    M.load_applications()
    if user_config then
        config = vim.tbl_deep_extend("force", config, user_config)
    end
end

function M.load_applications()
    local path = "/sdcard/Android/data/" .. PACKAGE .. "/files/activities.json"
    local file = io.open(path, "r")
    if not file then return end

    local content = file:read("*a")
    file:close()

    local ok, data = pcall(vim.fn.json_decode, content)
    if ok and type(data) == "table" then
        for _, app in ipairs(data) do
            if app.appName and app.packageName and app.activities and #app.activities > 0 then
                config.applications[app.appName] = {
                    name = app.appName,
                    activity = app.packageName .. "/" .. app.activities[1],
                }
            end
        end
    end
end

function M.install()
    if is_app_installed() then
        notify("ActivityLister is already installed.", vim.log.levels.INFO)
        return
    end

    if vim.fn.filereadable(APK_PATH) == 1 then
        do_open_installer()
    else
        do_download()
    end
end

function M.scan()
    if not is_app_installed() then
        notify("ActivityLister is not installed. Run :OpennerInstall first.", vim.log.levels.WARN)
        return
    end

    notify("Scanning applications...", vim.log.levels.INFO)
    vim.fn.jobstart(
        "am broadcast -a " .. PACKAGE .. ".ACTION_SCAN_AND_SAVE -n " .. PACKAGE .. "/.ScanAndSaveReceiver",
        {
            on_exit = function(_, code)
                vim.schedule(function()
                    if code == 0 then
                        vim.defer_fn(function()
                            config.applications = {}
                            M.load_applications()
                            notify("Applications loaded!", vim.log.levels.INFO)
                        end, 1000)
                    else
                        notify("Scan failed!", vim.log.levels.ERROR)
                    end
                end)
            end
        }
    )
end

function M.open()
    local apps = {}
    for _, app in pairs(config.applications) do
        table.insert(apps, app)
    end
    table.sort(apps, function(a, b) return a.name < b.name end)

    if #apps == 0 then
        notify("No applications found. Run :OpennerScan first.", vim.log.levels.WARN)
        return
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i, app in ipairs(apps) do
        table.insert(lines, string.format("[%d] %s", i, app.name))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = config.window.width
    local height = math.min(config.window.height, #lines)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = "minimal",
        border = config.window.border,
    })

    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "openner")
    vim.api.nvim_buf_set_var(buf, "apps", apps)

    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>close<CR>", { noremap = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>close<CR>", { noremap = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
        noremap = true,
        callback = function()
            local line = vim.api.nvim_win_get_cursor(0)[1]
            local idx = tonumber(string.match(
                vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1], "%[(%d+)%]"
            ))
            if idx and apps[idx] then
                local app = apps[idx]
                local command_parts = app.command or config.default_command
                local cmd = table.concat(command_parts, " ") .. " " .. vim.fn.shellescape(app.activity)
                
                notify("Opening: " .. app.name, vim.log.levels.INFO)
                
                local stdout_data = {}
                local stderr_data = {}
                
                vim.fn.jobstart(cmd, {
                    stdout_buffered = true,
                    stderr_buffered = true,
                    on_stdout = function(_, data)
                        if data then
                            vim.list_extend(stdout_data, data)
                        end
                    end,
                    on_stderr = function(_, data)
                        if data then
                            vim.list_extend(stderr_data, data)
                        end
                    end,
                    on_exit = function(_, exit_code)
                        vim.schedule(function()
                            if exit_code == 0 then
                                notify("Successfully opened: " .. app.name, vim.log.levels.INFO)
                            else
                                local error_msg = "Failed to open: " .. app.name
                                if #stderr_data > 0 then
                                    local stderr_str = table.concat(stderr_data, "\n")
                                    if stderr_str ~= "" then
                                        error_msg = error_msg .. "\nError: " .. stderr_str
                                    end
                                end
                                notify(error_msg, vim.log.levels.ERROR)
                            end
                        end)
                    end
                })
                
                vim.api.nvim_win_close(win, true)
            end
        end
    })
end

function M.uninstall()
    if not is_app_installed() then
        notify("ActivityLister is not installed.", vim.log.levels.WARN)
        return
    end
    vim.fn.jobstart("am start -a android.intent.action.DELETE -d package:" .. PACKAGE)
end

--- Opens a single application directly without showing the selection window
---
--- Useful for binding specific applications to keymaps or commands.
--- The application can be identified by its configuration key or name.
---
---@param app_to_find string The application key or name to open
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
        notify("Application not found: " .. app_to_find, vim.log.levels.ERROR)
        return
    end

    local app_name = app_config.name or app_key_found

    local command_parts = app_config.command or config.default_command
    local command_to_run = table.concat(command_parts, " ") .. " " .. vim.fn.shellescape(app_config.activity)

    notify("Opening: " .. app_name, vim.log.levels.INFO)

    local stdout_data = {}
    local stderr_data = {}

    vim.fn.jobstart(command_to_run, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                vim.list_extend(stdout_data, data)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.list_extend(stderr_data, data)
            end
        end,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if exit_code == 0 then
                    notify("Successfully opened: " .. app_name, vim.log.levels.INFO)
                else
                    local error_msg = "Failed to open: " .. app_name
                    if #stderr_data > 0 then
                        local stderr_str = table.concat(stderr_data, "\n")
                        if stderr_str ~= "" then
                            error_msg = error_msg .. "\nError: " .. stderr_str
                        end
                    end
                    notify(error_msg, vim.log.levels.ERROR)
                end
            end)
        end
    })
end

return M
