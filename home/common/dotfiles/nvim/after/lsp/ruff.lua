return {
	on_attach = function(client)
		-- Documentation and type information come from basedpyright.
		client.server_capabilities.hoverProvider = false
	end,
}
