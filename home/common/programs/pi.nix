# Shared across Desktop, WSL, and Darwin. Pi owns writable settings/auth/sessions;
# ~/.agents/skills is already deployed by agent-skills.nix and discovered by Pi.
{ inputs, pkgs, ... }:
let
  pi = pkgs.callPackage ../../../packages/pi {
    pi = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
    # Add fully built Pi package roots here, including their npm dependencies.
    piPackages = [ ];
    # npm is needed for trying packages with Pi's own package manager.
    runtimePackages = [ pkgs.nodejs_24 ];
  };
in
{
  home.packages = [ pi ];
}
