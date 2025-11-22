vim.api.nvim_create_autocmd("FileType", {
	pattern = "openner",
	callback = function()
		vim.opt_local.cursorline = true
	end,
})

vim.api.nvim_create_user_command("Openner", function()
	require("openner").open()
end, {})
