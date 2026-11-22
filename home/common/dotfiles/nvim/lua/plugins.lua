require("lazy").setup({
	{ "folke/lazy.nvim" },
	{
		"folke/tokyonight.nvim",
		config = function()
			require("tokyonight").setup({
				transparent = true,
				styles = {
					floats = "transparent",
				},
			})
		end,
	},
	require("plugins.lsp"),
	require("plugins.format"),
	require("plugins.lint"),
	require("plugins.dap"),
	require("plugins.misc"),
	require("plugins.ts"),
}, {
	lockfile = require("plugin-lock")(
		vim.fn.stdpath("config") .. "/lazy-lock.json",
		vim.fn.stdpath("state") .. "/lazy-lock.json"
	),
})
