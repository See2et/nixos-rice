{ pkgs, ... }:
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

}
