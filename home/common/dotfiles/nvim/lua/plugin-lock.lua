-- Keep Lazy updates writable; a changed declarative seed takes precedence on the next start.
return function(seed, lockfile)
	local contents = vim.fn.readfile(seed)
	local seed_hash = vim.fn.sha256(table.concat(contents, "\n"))
	local marker = lockfile .. ".seed"
	local previous = vim.fn.filereadable(marker) == 1 and vim.fn.readfile(marker)[1] or nil
	if previous ~= seed_hash or vim.fn.filereadable(lockfile) == 0 then
		vim.fn.mkdir(vim.fs.dirname(lockfile), "p")
		local temporary = lockfile .. "." .. vim.fn.getpid()
		assert(vim.fn.writefile(contents, temporary) == 0, "Cannot write Lazy lockfile")
		assert(vim.uv.fs_rename(temporary, lockfile))
		assert(vim.fn.writefile({ seed_hash }, marker) == 0, "Cannot write Lazy seed marker")
	end
	return lockfile
end
