return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufWritePost", "InsertLeave" },
	config = function()
		local lint = require("lint")

		local function textlint_cmd()
			if vim.fn.executable("textlint") == 1 then
				return "textlint"
			end

			return nil
		end

		lint.linters.textlint = {
			cmd = textlint_cmd,
			stdin = true,
			append_fname = false,
			args = {
				"--format",
				"json",
				"--stdin",
				"--stdin-filename",
				function()
					return vim.api.nvim_buf_get_name(0)
				end,
			},
			stream = "both",
			ignore_exitcode = true,
			parser = function(output, bufnr)
				-- Let nvim-lint expose parse/configuration failures instead of clearing diagnostics silently.
				local decoded = vim.json.decode(output)
				assert(type(decoded) == "table" and vim.islist(decoded), "Expected textlint JSON results")

				local diagnostics = {}
				for _, file_result in ipairs(decoded) do
					for _, message in ipairs(file_result.messages or {}) do
						local lnum = math.max((message.line or 1) - 1, 0)
						local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ""
						local column = math.max((message.column or 1) - 1, 0)
						local col = vim.str_byteindex(line, "utf-16", column, false)
						local next_char = vim.str_utfindex(line, "utf-32", col, false) + 1
						local end_col = vim.str_byteindex(line, "utf-32", next_char, false)
						table.insert(diagnostics, {
							lnum = lnum,
							end_lnum = lnum,
							col = col,
							end_col = end_col,
							message = message.message or "textlint warning",
							source = message.ruleId and ("textlint:" .. message.ruleId) or "textlint",
							severity = message.severity == 2 and vim.diagnostic.severity.ERROR
								or vim.diagnostic.severity.WARN,
						})
					end
				end

				return diagnostics
			end,
		}

		lint.linters_by_ft = {
			markdown = { "markdownlint-cli2" },
		}

		local group = vim.api.nvim_create_augroup("nvim_lint_autocmd", { clear = true })
		vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
			group = group,
			callback = function(args)
				if vim.bo[args.buf].buftype ~= "" then
					return
				end

				lint.try_lint()

				local ft = vim.bo[args.buf].filetype
				if textlint_cmd() ~= nil and (ft == "markdown" or ft == "text") then
					lint.try_lint("textlint")
				end
			end,
		})
	end,
}
