return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "InsertLeave" },
    config = function()
        local lint = require("lint")

        local function textlint_cmd()
            if vim.fn.executable("textlint") == 1 then
                return "textlint"
            end

            local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/textlint"
            if vim.fn.executable(mason_bin) == 1 then
                return mason_bin
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
            stream = "stdout",
            ignore_exitcode = true,
            parser = function(output)
                local ok, decoded = pcall(vim.json.decode, output)
                if not ok or type(decoded) ~= "table" then
                    return {}
                end

                local diagnostics = {}
                for _, file_result in ipairs(decoded) do
                    for _, message in ipairs(file_result.messages or {}) do
                        local lnum = math.max((message.line or 1) - 1, 0)
                        local col = math.max((message.column or 1) - 1, 0)
                        table.insert(diagnostics, {
                            lnum = lnum,
                            end_lnum = lnum,
                            col = col,
                            end_col = col + 1,
                            message = message.message or "textlint warning",
                            source = message.ruleId and ("textlint:" .. message.ruleId) or "textlint",
                            severity = vim.diagnostic.severity.WARN,
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
        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
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
