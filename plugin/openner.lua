vim.api.nvim_create_user_command("Openner", function()
	require("Openner").open()
end, {})
