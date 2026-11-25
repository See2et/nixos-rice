{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  bb = pkgs.callPackage ../../packages/bb { };
  bbFactory = pkgs.callPackage ../../packages/bb-factory {
    inherit bb;
    src = inputs.bb-factory;
  };
  agy = pkgs.callPackage ../../packages/agy { };
  claude = pkgs.callPackage ../../packages/claude-code { };
  codex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  merge = ../common/programs/merge-agent-config.py;
  trustedWorkspaces = import ../../lib/agent-trusted-workspaces.nix config.home.homeDirectory;
  claudeTrust = pkgs.writeText "claude-workspace-trust.json" (
    builtins.toJSON {
      projects = lib.genAttrs trustedWorkspaces (_: {
        hasTrustDialogAccepted = true;
      });
    }
  );
  agyTrust = pkgs.writeText "agy-workspace-trust.json" (
    builtins.toJSON { inherit trustedWorkspaces; }
  );
  settings = pkgs.writeText "bb-settings.json" (
    builtins.toJSON {
      config.BB_APP_URL = "https://nixos.taile209b8.ts.net:38886";
      sharedSkillRoots = {
        user = [ ".agents/skills" ];
        project = [ ".agents/skills" ];
      };
    }
  );
  mcp = pkgs.writeText "agy-mcp.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (
        _: server:
        (builtins.removeAttrs server [ "url" ])
        // lib.optionalAttrs (server ? url) { serverUrl = server.url; }
        // {
          disabled = false;
        }
      ) (import ../../lib/agent-mcp.nix);
    }
  );
  manifest = pkgs.writeText "bb-plugins.json" (
    builtins.toJSON {
      plugins =
        (map
          (name: {
            id = name;
            source = "builtin:${name}";
          })
          [
            "provider-codex"
            "provider-claude-code"
            "provider-acp"
            "ask-user-question"
            "browser-automation"
            "tasks"
            "workflows"
            "push-notifications"
            "environment-git-worktree"
            "monaco-editor"
          ]
        )
        ++ [
          {
            id = "bb-antigravity-usage";
            # PR #3 reads quota through agy /usage with the current sign-in storage.
            source = "git:https://github.com/mrdavidlaing/bb-antigravity-usage.git@b78b04eed930c087da7c5d6217102d3f5a11d03c";
          }
          {
            id = "miloa-management";
            source = "path:${config.home.homeDirectory}/ghq/github.com/see2et/miloa-management";
          }
          {
            id = "mentor";
            source = "path:${config.home.homeDirectory}/ghq/github.com/see2et/bb-mentor";
          }
        ];
      agy = {
        id = "agy";
        displayName = "Antigravity";
        command = "${agy}/bin/agy";
        args = [
          "acp"
          "--disable-telemetry"
        ];
      };
    }
  );
  prepare = pkgs.writeShellScript "bb-prepare" ''
    set -eu
    ${pkgs.python3}/bin/python3 ${merge} "$HOME/.bb/config.json" ${settings}
    ${pkgs.python3}/bin/python3 ${merge} "$HOME/.gemini/config/mcp_config.json" ${mcp}
  '';
in
{
  imports = [ ../common/programs/bb-client.nix ];
  home.packages = [
    bb
    bbFactory
  ];
  home.file.".bb/skills/bb-factory".source = "${bbFactory}/share/bb/skills/bb-factory";
  home.activation.agentWorkspaceTrust = lib.hm.dag.entryAfter [ "writeBoundary" "sharedAgentMcp" ] ''
    run ${pkgs.python3}/bin/python3 ${merge} \
      "${config.home.homeDirectory}/.claude.json" ${claudeTrust}
    run ${pkgs.python3}/bin/python3 ${merge} \
      "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json" ${agyTrust} \
      --append-list trustedWorkspaces
  '';
  systemd.user.services.bb = {
    Unit = {
      Description = "bb coding-agent server and local execution host";
      After = [ "network-online.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "BB_TELEMETRY=false"
        "BB_BIN=${bb}/bin/bb"
        "BB_SERVER_URL=http://127.0.0.1:38886"
        "PATH=${
          lib.makeBinPath [
            bb
            bbFactory
            agy
            claude
            codex
            pkgs.nodejs_24
            pkgs.git
            pkgs.gh
            pkgs.chromium
            pkgs.curl
            pkgs.openssh
            pkgs.bash
            pkgs.zsh
            pkgs.coreutils
            pkgs.procps
            pkgs.gnutar
            pkgs.gzip
            pkgs.unzip
            pkgs.ripgrep
            pkgs.jq
          ]
        }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      ExecStartPre = prepare;
      ExecStart = "${bb}/bin/bb-app --data-dir %h/.bb --server-bind-host 127.0.0.1 --server-port 38886 --host-daemon-port 38887 --no-in-app-updates --bundled";
      ExecStartPost = "${pkgs.python3}/bin/python3 ${./scripts/configure-bb.py} ${manifest}";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStartSec = 180;
      TimeoutStopSec = 45;
      KillMode = "control-group";
    };
  };
}
