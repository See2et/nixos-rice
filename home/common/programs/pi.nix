# Shared across Desktop, WSL, and Darwin. Pi owns writable settings/auth/sessions;
# ~/.agents/skills is already deployed by agent-skills.nix and discovered by Pi.
{ inputs, pkgs, ... }:
let
  subagents = pkgs.callPackage ../../../packages/pi-subagents {
    src = inputs.pi-subagents;
  };
  validatorPython = pkgs.python3.withPackages (ps: [ ps.jsonschema ]);
  pi = pkgs.callPackage ../../../packages/pi {
    pi = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    piPackages = [
      subagents
      inputs.pi-astraeus
    ];
    # npm is needed for trying packages with Pi's own package manager.
    runtimePackages = [
      pkgs.nodejs_24
      validatorPython
    ];
  };
in
{
  home.packages = [ pi ];
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
