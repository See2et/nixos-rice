{ pkgs, lib, ... }:
let
  gmailMcp = pkgs.writeShellApplication {
    name = "gmail-multi-account-mcp";
    runtimeInputs = [
      pkgs.nodejs_24
      pkgs.ghq
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.libsecret
      pkgs.xdg-utils
    ];
    text = ''
      repo="''${GMAIL_MCP_REPO:-}"
      if [[ -z "$repo" ]]; then
        mapfile -t matches < <(ghq list --full-path gmail-multi-account-mcp)
        if [[ "''${#matches[@]}" != 1 ]]; then
          echo 'Expected one ghq checkout of gmail-multi-account-mcp; clone/build it or set GMAIL_MCP_REPO.' >&2
          exit 1
        fi
        repo="''${matches[0]}"
      fi
      if [[ "$repo" != /* || ! -f "$repo/dist/cli.js" ]]; then
        echo 'GMAIL_MCP_REPO must be an absolute, built checkout (npm ci && npm run build).' >&2
        exit 1
      fi
      ${lib.optionalString pkgs.stdenv.isLinux ''export GMAIL_MCP_SECRET_TOOL="${pkgs.libsecret}/bin/secret-tool"''}
      exec node "$repo/dist/cli.js" "$@"
    '';
  };
in
{
  environment.systemPackages = [
    gmailMcp
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.libsecret
    pkgs.xdg-utils
  ];
  environment.etc."codex/config.toml".text = builtins.readFile ./config.toml + ''

    [mcp_servers.gmail-multi-account]
    command = "${gmailMcp}/bin/gmail-multi-account-mcp"
    args = ["serve"]
    enabled = true
  '';
}
