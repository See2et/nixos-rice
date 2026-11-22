-- Run from the repository root: nvim --headless -u NONE -l tests/neovim.lua
local config = vim.fn.getcwd() .. "/home/common/dotfiles/nvim"
vim.opt.runtimepath:prepend(config)

local lint = { linters = {} }
package.loaded.lint = lint
require("plugins.lint").config()

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "日本😀語です" })
local output = vim.json.encode({
	{
		messages = {
			{ line = 1, column = 5, message = "Japanese position", ruleId = "example", severity = 2 },
		},
	},
})
local diagnostics = lint.linters.textlint.parser(output, 0)
assert(diagnostics[1].col == 10, "textlint UTF-16 columns must become byte columns")
assert(diagnostics[1].end_col == 13, "textlint range must cover a complete character")
assert(diagnostics[1].severity == vim.diagnostic.severity.ERROR, "preserve textlint severity")
assert(not pcall(lint.linters.textlint.parser, "textlint configuration failed", 0), "report invalid output")
assert(#lint.linters.textlint.parser("[]", 0) == 0, "valid clean output has no diagnostics")

local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, "p")
local ok, err = pcall(function()
	local seed, lockfile = temporary .. "/seed.json", temporary .. "/state/lazy-lock.json"
	local prepare = require("plugin-lock")
	vim.fn.writefile({ '{"version":1}' }, seed)
	assert(prepare(seed, lockfile) == lockfile)
	assert(vim.fn.readfile(lockfile)[1] == '{"version":1}', "seed a writable runtime lock")
	vim.fn.writefile({ '{"localUpdate":true}' }, lockfile)
	prepare(seed, lockfile)
	assert(vim.fn.readfile(lockfile)[1] == '{"localUpdate":true}', "retain Lazy updates across restarts")
	vim.fn.writefile({ '{"version":2}' }, seed)
	prepare(seed, lockfile)
	assert(vim.fn.readfile(lockfile)[1] == '{"version":2}', "apply changed declarative pins")
end)
vim.fn.delete(temporary, "rf")
assert(ok, err)

print("neovim checks passed")
