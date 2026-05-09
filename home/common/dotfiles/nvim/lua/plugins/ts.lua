return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "master",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"markdown",
					"markdown_inline",
					"lua",
					"typescript",
					"rust",
				},
				highlight = {
					enable = true,
					auto_install = true,
				},
				sync_install = true,
				indent = {
					enable = true,
				},
				autotag = {
					enable = true,
				},
			})
		end,
		dependencies = { "windwp/nvim-ts-autotag" },
	},
}
