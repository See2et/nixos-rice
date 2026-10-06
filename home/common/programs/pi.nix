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
      "${extensions}/node_modules/pi-web-access"
      "${extensions}/node_modules/pi-interview"
      "${extensions}/node_modules/@raidou/pi-notify"
    ];
    # npm is needed for trying packages with Pi's own package manager.
    runtimePackages = [
      pkgs.nodejs_24
      validatorPython
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
  home.file = builtins.listToAttrs (
    map
      (role: {
        name = ".pi/agent/agents/astraeus-${role}.md";
        value.source = "${inputs.pi-astraeus}/agents/astraeus-${role}.md";
      })
      [
        "worker"
        "reviewer"
        "adjudicator"
      ]
  );
}
