{ pkgs, ... }:

let
  homePreview = pkgs.writeShellApplication {
    name = "home-preview";
    runtimeInputs = [
      pkgs.python3
      pkgs.tailscale
    ];
    text = ''
      exec python3 ${./scripts/home-preview.py} "$@"
    '';
  };
in
{
  environment.systemPackages = [ homePreview ];
}
