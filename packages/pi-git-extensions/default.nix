{
  lib,
  buildNpmPackage,
  nodejs_24,
  runCommand,
  writeText,
  src,
  extensionName,
  pin,
}:
let
  manifest = writeText "${extensionName}-package.json" (builtins.toJSON pin.manifest);
  lock = writeText "${extensionName}-package-lock.json" (builtins.toJSON pin.packageLock);
  hasDependencies =
    (pin.manifest.dependencies or { }) != { } || (pin.manifest.optionalDependencies or { }) != { };
in
assert lib.assertMsg (
  pin.rev == src.rev
) "${extensionName}: runtime dependency pin is stale; run update-pi-extensions ${extensionName}";
if !hasDependencies then
  runCommand extensionName { } ''
    cp -R ${src} "$out"
    chmod -R u+w "$out"
    cp ${manifest} "$out/package.json"
  ''
else
  buildNpmPackage {
    pname = extensionName;
    version = pin.manifest.version;
    inherit src;
    nodejs = nodejs_24;
    npmDepsHash = pin.npmDepsHash;
    postPatch = ''
      cp ${manifest} package.json
      cp ${lock} package-lock.json
      rm -f .npmrc
    '';
    npmFlags = [
      "--legacy-peer-deps"
      "--ignore-scripts"
    ];
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R . "$out/"
      runHook postInstall
    '';
    meta.platforms = lib.platforms.unix;
  }
