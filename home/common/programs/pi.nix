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
  extensionInputs = inputs.pi-extensions.inputs;
  extensions = pkgs.callPackage ../../../packages/pi-extensions { };
  inventory = builtins.fromJSON (builtins.readFile ../../../pi-extensions/inventory.json);
  extensionSource = entry: extensionInputs.${entry.name};
  extensionPackage =
    entry:
    if entry.kind == "npm" then
      "${extensions}/node_modules/${entry.package}"
    else if entry.kind == "git" then
      if entry ? packaging then
        pkgs.callPackage (../../../packages + "/${entry.packaging}") {
          src = extensionSource entry;
        }
      else
        extensionSource entry
    else
      throw "Unknown Pi extension route: ${entry.kind}";
  agentFiles = lib.concatMap (
    entry:
    map (role: {
      name = ".pi/agent/agents/${entry.agents.prefix}-${role}.md";
      value.source = "${extensionSource entry}/agents/${entry.agents.prefix}-${role}.md";
    }) (entry.agents.roles or [ ])
  ) inventory;
  validatorPython = pkgs.python3.withPackages (ps: [ ps.jsonschema ]);
  pi = pkgs.callPackage ../../../packages/pi {
    pi = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    piPackages = map extensionPackage inventory;
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
  # Own only recap's model, not Pi settings/auth. Keep this writable so
  # /recap config works; the next HM activation restores the declarative model.
  home.activation.piRecap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${../../../packages/pi-extensions/configure-recap.py} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.pi/agent/extensions/pi-recap.json"} \
      ${lib.escapeShellArg "openai-codex/gpt-6.1-sol"}
  '';
  home.file = builtins.listToAttrs agentFiles;
}
