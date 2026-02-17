local M = {}

-- Default configuration
local config = {
    window = { width = 50, height = 10, border = "rounded" },
    default_command = { "am", "start", "--user", "0", "-n" },
    applications = {},
}

-- Setup plugin
function M.setup(user_config)
    M.load_applications()
    if user_config then
        config = vim.tbl_deep_extend("force", config, user_config)
    end
end

-- Load applications from activities.json
function M.load_applications()
    local path = "/sdcard/Android/data/com.activity.lister/files/activities.json"
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

function M.open()
    local apps = {}
    for _, app in pairs(config.applications) do
        table.insert(apps, app)
    end
    
    table.sort(apps, function(a, b) return a.name < b.name end)

    if #apps == 0 then
        vim.notify("found 0 applications", vim.log.levels.WARN)
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
    
    vim.api.nvim_buf_set_var(buf, "apps", apps)

    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>close<CR>", { noremap = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>close<CR>", { noremap = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
        noremap = true,
        callback = function()
            local line = vim.api.nvim_win_get_cursor(0)[1]
            local idx = tonumber(string.match(vim.api.nvim_buf_get_lines(buf, line-1, line, false)[1], "%[(%d+)%]"))
            if idx and apps[idx] then
                local app = apps[idx]
                local cmd = table.concat(config.default_command, " ") .. " " .. vim.fn.shellescape(app.activity)
                vim.fn.jobstart(cmd)
                vim.api.nvim_win_close(win, true)
            end
        end
    })
end

function M.scan()
    vim.notify("Scanning applications...", vim.log.levels.INFO)
    vim.fn.jobstart("am broadcast -a com.activity.lister.ACTION_SCAN_AND_SAVE -n com.activity.lister/.ScanAndSaveReceiver", {
        on_exit = function(_, code)
            if code == 0 then
                vim.defer_fn(function()
                    config.applications = {}
                    M.load_applications()
                    vim.notify("applications has been loaded", vim.log.levels.INFO)
                end, 1000)
            end
        end
    })
end

-- Uninstall helper app
function M.uninstall()
    vim.fn.jobstart("am start -a android.intent.action.DELETE -d package:com.activity.lister")
end

return M
