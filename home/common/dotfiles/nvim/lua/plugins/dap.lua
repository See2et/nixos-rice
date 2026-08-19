return {
	"mfussenegger/nvim-dap",
	dependencies = {
		{
			"mfussenegger/nvim-dap-python",
			config = function()
				require("dap-python").setup(vim.fn.exepath("python-debugpy"))
			end,
		},
	},
}
