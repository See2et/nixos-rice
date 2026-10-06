{
  lib,
  symlinkJoin,
  makeWrapper,
  pi,
  piPackages ? [ ],
  runtimePackages ? [ ],
}:
let
  wrapperArgs = lib.escapeShellArgs (
    lib.optionals (runtimePackages != [ ]) [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath runtimePackages)
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
