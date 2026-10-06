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
  npmDepsHash = "sha256-yf0DF7eq4CBgroYPuoB+LmHCShX75vL44zLUxc274R0=";
  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;
  # Bun/Jiti exposes fs through a Proxy. Caching an immutable Symbol property
  # on that object breaks repeated lock probes; keep the same precision cache
  # in a WeakMap instead. Lock acquisition/staleness behavior is unchanged.
  postConfigure = ''
    substituteInPlace node_modules/proper-lockfile/lib/mtime-precision.js \
      --replace-fail 'const cacheSymbol = Symbol();' 'const precisionCache = new WeakMap();' \
      --replace-fail 'const cachedPrecision = fs[cacheSymbol];' 'const cachedPrecision = precisionCache.get(fs);' \
      --replace-fail 'Object.defineProperty(fs, cacheSymbol, { value: precision });' 'precisionCache.set(fs, precision);'
  '';
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
