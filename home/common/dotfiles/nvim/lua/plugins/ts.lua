local parsers = {
	"markdown",
	"markdown_inline",
	"lua",
	"python",
	"javascript",
	"typescript",
	"tsx",
	"rust",
}

-- A separate directory keeps legacy parser copies from shadowing matching queries.
local install_dir = vim.fn.stdpath("data") .. "/treesitter"

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = function()
			local treesitter = require("nvim-treesitter")
			treesitter.setup({ install_dir = install_dir })
			-- install() alone skips existing parsers, leaving stale parser/query pairs after updates.
			assert(
				treesitter.install(parsers, { force = true }):wait(300000),
				"Treesitter parser/query installation failed"
			)
			for _, lang in ipairs(parsers) do
				assert(vim.uv.fs_stat(install_dir .. "/parser/" .. lang .. ".so"), "Missing parser: " .. lang)
			end
		end,
		config = function()
			require("nvim-treesitter").setup({ install_dir = install_dir })

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
				pattern = {
					"markdown",
					"lua",
					"python",
					"javascript",
					"javascriptreact",
					"typescript",
					"typescriptreact",
					"rust",
				},
				callback = function(args)
					local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
					local ok, err = pcall(vim.treesitter.start, args.buf, lang)
					if not ok then
						vim.notify_once(
							"Treesitter: " .. tostring(err) .. ". Run :Lazy build nvim-treesitter to repair parsers.",
							vim.log.levels.WARN
						)
						return
					end
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
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
