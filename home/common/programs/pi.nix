# Shared across Desktop, WSL, and Darwin. Pi owns writable settings/auth/sessions;
# ~/.agents/skills is already deployed by agent-skills.nix and discovered by Pi.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  extensions = pkgs.callPackage ../../../packages/pi-extensions { };
  subagents = pkgs.callPackage ../../../packages/pi-subagents {
    src = inputs.pi-subagents;
  };
  validatorPython = pkgs.python3.withPackages (ps: [ ps.jsonschema ]);
  pi = pkgs.callPackage ../../../packages/pi {
    pi = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    piPackages = [
      subagents
      inputs.pi-astraeus
      inputs.pi-understanding
      "${extensions}/node_modules/pi-web-access"
      "${extensions}/node_modules/pi-browser-actions"
      "${extensions}/node_modules/pi-interview"
      "${extensions}/node_modules/@raidou/pi-notify"
      "${extensions}/node_modules/pi-lsp-extension"
      "${extensions}/node_modules/@mtrojnar/pi-usage"
    ];
    # Use the Nix browser on Linux instead of downloading an unpatched
    # Playwright browser. User-supplied overrides remain authoritative.
    environmentDefaults = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      PLAYWRIGHT_MCP_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
    };
    runtimeLibraries = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];
    # npm is needed for trying packages with Pi's own package manager.
    runtimePackages = [
      pkgs.nodejs_24
      # Scope resolution uses Git; PR metadata uses the user's existing gh auth.
      pkgs.git
      pkgs.gh
      validatorPython
      pkgs.typescript-language-server
      pkgs.typescript
      pkgs.pyright
      pkgs.rust-analyzer
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.libnotify
      pkgs.xdg-utils
    ];
  };
in
{
  home.packages = [ pi ];
  # Keep Pi's settings writable; merge only the notification integration we own.
  home.activation.piNotifications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${../../../packages/pi-extensions/configure-notifications.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/settings.json"}
  '';
  home.activation.piCodeMode = lib.hm.dag.entryAfter [ "piNotifications" ] ''
    run ${pkgs.python3}/bin/python3 ${../../../packages/pi-extensions/configure-codemode.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/settings.json"}
  '';
  home.file = builtins.listToAttrs (
    map
      (role: {
        name = ".pi/agent/agents/astraeus-${role}.md";
        value.source = "${inputs.pi-astraeus}/agents/astraeus-${role}.md";
      })
      [
        "worker"
        "designer"
        "reviewer"
        "adjudicator"
      ]
  );
}
