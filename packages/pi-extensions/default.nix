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
      ./browser-preview.mjs
    ];
  };
  nodejs = nodejs_24;
  # Preserve sharp's upstream $ORIGIN RPATHs; the Pi wrapper supplies libstdc++.
  # The scoped npm override pins patched sharp (GHSA-wq5f-xc86-pv6w).
  dontPatchELF = true;
  npmDepsHash = "sha256-5DfbUxdeBr1cgMTEhtBA8NxeEGS3I/Ck4Z3pwU1oj5A=";
  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;
  # Bun/Jiti exposes fs through a Proxy. Caching an immutable Symbol property
  # on that object breaks repeated lock probes; keep the same precision cache
  # in a WeakMap instead. Lock acquisition/staleness behavior is unchanged.
  postConfigure = ''
    # Both browser-actions and web-access register web_search. Keep existing
    # web-access discovery/provider behavior and give the browser helper a
    # distinct name rather than silently replacing either tool.
    cp ${./browser-preview.mjs} node_modules/pi-browser-actions/src/nix-preview.mjs
    substituteInPlace node_modules/pi-browser-actions/src/index.ts \
      --replace-fail 'name: "web_search",' 'name: "browser_web_search",' \
      --replace-fail 'const { default: sharp } = await import("sharp");' 'const { renderPreview } = await import("./nix-preview.mjs");' \
      --replace-fail 'const fullMetadata = await sharp(fullImage).metadata();' 'let fullMetadata;' \
      --replace-fail 'await sharp(fullImage)
					.resize({
						width: SCREENSHOT_PREVIEW_MAX_DIMENSION,
						height: SCREENSHOT_PREVIEW_MAX_DIMENSION,
						fit: "inside",
						withoutEnlargement: true,
					})
					.jpeg({ quality: 75 })
					.toFile(previewPath);' 'const rendered = await renderPreview(artifactPath, previewPath, SCREENSHOT_PREVIEW_MAX_DIMENSION); fullMetadata = rendered.fullMetadata;' \
      --replace-fail 'const previewMetadata = await sharp(preview).metadata();' 'const previewMetadata = rendered.previewMetadata;'
    # The Pi input is a compiled Bun executable, not the Node interpreter.
    # Playwright's CLI must run with our pinned runtime Node, not process.execPath.
    substituteInPlace node_modules/pi-browser-actions/src/runtime.ts \
      --replace-fail 'spawn(process.execPath, [cliPath, ...args]' 'spawn("node", [cliPath, ...args]'
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
