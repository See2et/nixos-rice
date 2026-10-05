{ lib, pkgs, ... }:
let
  command =
    name: mode:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.python3 ];
      text = ''
        exec python3 ${./.}/skills_audit.py ${mode} "$@"
      '';
    };
in
{
  home.packages = [
    (command "skills-update" "update")
    (command "skills-audit" "review")
  ];

  # Only interactive Zsh calls are intercepted; Python invokes the real executable.
  programs.zsh.initContent = lib.mkAfter ''
    function nix() {
      if [[ "''${1-}" == flake && "''${2-}" == update ]]; then
        command skills-update "$@"
      else
        command nix "$@"
      fi
    }
  '';
}
