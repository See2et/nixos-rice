{
  config,
  lib,
  pkgs,
  ...
}:
let
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  url = if darwin then "https://nixos.taile209b8.ts.net:38886" else "http://127.0.0.1:38886";
  directory =
    if darwin then
      "${config.home.homeDirectory}/Library/Application Support/bb"
    else
      "${config.xdg.configHome}/bb";
  target = "${directory}/server-target.json";
  initial = pkgs.writeText "bb-client-server.json" (
    builtins.toJSON {
      target = "custom";
      customServerUrl = url;
      customServerUrls = [ url ];
      customServerNames = {
        ${url} = "NixOS";
      };
      showBuiltinServer = false;
    }
  );
in
{
  home.packages = [ (pkgs.callPackage ../../../packages/bb-desktop { }) ];
  # Seed once. Subsequent server selections and native app state remain user-owned.
  home.activation.bbClient = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${lib.escapeShellArg target} ] && [ ! -L ${lib.escapeShellArg target} ]; then
      run ${pkgs.python3}/bin/python3 ${./merge-agent-config.py} \
        ${lib.escapeShellArg target} ${initial}
    fi
  '';
}
