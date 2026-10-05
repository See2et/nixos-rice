return {
	on_init = function(client)
		local python = client.config.settings.python or {}
		if python.pythonPath then
			return
		end

		-- Prefer the project's environment; fall back to an activated venv/Conda env.
		local root = client.config.root_dir or vim.fn.getcwd()
		local environments = { root .. "/.venv", root .. "/venv" }
		for _, name in ipairs({ "VIRTUAL_ENV", "CONDA_PREFIX" }) do
			if vim.env[name] then
				table.insert(environments, vim.env[name])
			end
		end
		for _, environment in ipairs(environments) do
			local executable = environment .. "/bin/python"
			if vim.fn.executable(executable) == 1 then
				python.pythonPath = executable
				client.config.settings.python = python
				client.settings.python = python
				client:notify("workspace/didChangeConfiguration", { settings = client.settings })
				break
			end
		end
	end,
	settings = {
		basedpyright = {
			disableOrganizeImports = true, -- Ruff owns import actions.
			analysis = {
				autoImportCompletions = true,
				autoSearchPaths = true,
				diagnosticMode = "openFilesOnly",
				typeCheckingMode = "standard",
			},
		},
	},
}
