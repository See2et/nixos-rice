return {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
        formatters_by_ft = {
            nix = { "nixfmt" },
            rust = { "rustfmt" },
            javascript = { "deno_fmt" },
            javascriptreact = { "deno_fmt" },
            typescript = { "deno_fmt" },
            typescriptreact = { "deno_fmt" },
            json = { "deno_fmt" },
            jsonc = { "deno_fmt" },
            markdown = { "deno_fmt" },
        },
        format_on_save = {
            timeout_ms = 500,
            lsp_format = "fallback",
        },
    },
}
