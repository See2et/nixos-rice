{
  lib,
  buildNpmPackage,
  nodejs_24,
}:
buildNpmPackage {
  pname = "pi-extensions";
  version = "1.0.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };
  nodejs = nodejs_24;
  npmDepsHash = "sha256-8xaFS5C2xV6B+VnhcJ6aGjJNiws52FCtGodNwbap+rs=";
  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R node_modules package.json "$out/"
    runHook postInstall
  '';
  meta = {
    description = "Pinned Pi extensions and their runtime npm dependencies";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
