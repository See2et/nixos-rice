local parsers = {
	"markdown",
	"markdown_inline",
	"lua",
	"python",
	"typescript",
	"rust",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = function()
			local treesitter = require("nvim-treesitter")
			assert(
				type(treesitter.install) == "function",
				"nvim-treesitter main API missing during build; run :Lazy sync and restart Neovim."
			)

			treesitter.install(parsers):wait(300000)
		end,
		config = function()
			local treesitter = require("nvim-treesitter")

			if type(treesitter.install) ~= "function" then
				vim.schedule(function()
					vim.notify_once(
						"nvim-treesitter is on a stale checkout; run :Lazy sync and restart Neovim.",
						vim.log.levels.WARN,
						{ title = "nvim-treesitter" }
					)
				end)
				return
			end

			treesitter.setup({})

			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"markdown",
					"lua",
					"python",
					"typescript",
					"rust",
				},
				callback = function()
					vim.treesitter.start()
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
		dependencies = {
			{
				"windwp/nvim-ts-autotag",
				config = function()
					require("nvim-ts-autotag").setup()
				end,
			},
		},
	},
}
