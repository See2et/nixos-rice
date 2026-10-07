{
  lib,
  buildNpmPackage,
  nodejs_24,
  jq,
  src,
}:

buildNpmPackage {
  pname = "pi-subagents";
  version = (lib.importJSON "${src}/package.json").version;
  inherit src;
  nodejs = nodejs_24;
  # RPC callers may omit description. Keep completion delivery actionable and
  # surface synchronous notification failures instead of silently losing them.
  patches = [ ./completion-notification.patch ];
  # Upstream's development lock entries lack integrity hashes. Retain the
  # exact upstream runtime dependency graph; Pi supplies its own peer APIs.
  postPatch = ''
    ${jq}/bin/jq 'del(.devDependencies, .peerDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
    ${jq}/bin/jq '.packages |= with_entries(select(.key == "" or .value.dev != true)) |
        .packages[""] |= del(.devDependencies, .peerDependencies)' \
      package-lock.json > package-lock.json.tmp
    mv package-lock.json.tmp package-lock.json
  '';
  npmDepsHash = "sha256-w/xgaubF+4hNpFMcoezwXAp2q6akKtMW2p2GUH3d4w8=";
  npmFlags = [ "--omit=dev" ];
  dontNpmBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test ${./notification.test.mjs}
    runHook postCheck
  '';

  # Pi loads TypeScript directly; retain the package root and runtime modules.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R src node_modules package.json LICENSE "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Pi subagent orchestration extension";
    homepage = "https://github.com/tintinweb/pi-subagents";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
