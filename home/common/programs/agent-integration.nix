{
  config,
  lib,
  pkgs,
  ...
}:
let
  servers = import ../../../lib/agent-mcp.nix;
  patch = pkgs.writeText "shared-agent-mcp.json" (builtins.toJSON { mcpServers = servers; });
  claudePatch = pkgs.writeText "claude-agent-mcp.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (
        _: server:
        server
        // {
          type = if server ? url then "http" else "stdio";
        }
      ) servers;
    }
  );
in
{
  home.activation.sharedAgentMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${./merge-agent-config.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.claude.json"} ${claudePatch}
    run ${pkgs.python3}/bin/python3 ${./merge-agent-config.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/mcp.json"} ${patch}
  '';
}
