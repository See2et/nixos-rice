{
  lib,
  symlinkJoin,
  makeWrapper,
  pi,
  piPackages ? [ ],
  runtimePackages ? [ ],
  runtimeLibraries ? [ ],
  environmentDefaults ? { },
}:
let
  wrapperArgs = lib.escapeShellArgs (
    lib.optionals (runtimePackages != [ ]) [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath runtimePackages)
    ]
    ++ lib.optionals (runtimeLibraries != [ ]) [
      "--prefix" "LD_LIBRARY_PATH" ":" (lib.makeLibraryPath runtimeLibraries)
    ]
    ++ lib.concatLists (lib.mapAttrsToList (name: value: [ "--set-default" name value ]) environmentDefaults)
    # Pi dispatches CLI subcommands before parsing session options. Prefixing -e
    # hides the subcommand and breaks e.g. `pi mcp add --url ...`. Keep the same
    # runtime PATH/environment, but don't inject session extensions in CLI mode.
    ++ [
      "--run"
      ''case "''${1-}" in install|remove|uninstall|update|list|config|auth|mcp) exec ${lib.getExe pi} "$@" ;; esac''
    ]
    ++ lib.optionals (piPackages != [ ]) [
      "--add-flags"
      (lib.escapeShellArgs (
        lib.concatMap (package: [
          "-e"
          "${package}"
        ]) piPackages
      ))
    ]
  );
in
symlinkJoin {
  name = "pi-configured-${pi.version}";
  inherit (pi) version meta;
  paths = [ pi ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/pi ${wrapperArgs}
  '';
  passthru.unwrapped = pi;
}
