{ pkgs }:
pkgs.buildNpmPackage {
  pname = "bb-app";
  version = "0.50.1";
  src = pkgs.lib.fileset.toSource {
    root = ./.;
    fileset = pkgs.lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };
  nodejs = pkgs.nodejs_24;
  npmDepsHash = "sha256-08UBpHeYzR5/cBjCcoJs8MESiCk98wtAP5uDM2nIBRE=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/bb" "$out/bin"
    cp -R node_modules "$out/lib/bb/"
    # Keep only the native artifacts for this host before patching ELF files.
    find "$out/lib/bb/node_modules" -type d \
      \( -name 'darwin-*' -o -name 'win32-*' -o -name 'linux-arm*' \
      -o -name 'android-*' -o -name 'ios-*' -o -name 'linuxmusl-*' \) \
      -prune -exec rm -rf {} +
    find "$out/lib/bb/node_modules" -type f \
      \( -name '*.node' -o -name '*.bare' \) \
      ! -path '*/linux-x64/*' ! -name 'linux-x64.node' \
      ! -path '*/watcher-linux-x64-glibc/*' -delete
    for command in bb bb-app bb-server bb-host-daemon; do
      makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/$command" \
        --add-flags "$out/lib/bb/node_modules/bb-app/dist/$command.js"
    done
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/bb-home"
    mkdir -p "$HOME"
    "$out/bin/bb-app" --help
    ${pkgs.nodejs_24}/bin/node - <<'JS'
    const root = process.env.out + '/lib/bb/node_modules/';
    const db = new (require(root + 'better-sqlite3'))(':memory:');
    if (db.prepare('select 42 as answer').get().answer !== 42) process.exit(1);
    db.close();
    require(root + 'node-pty');
    require(root + '@parcel/watcher');
    require(root + 'fs-native-extensions');
    JS
    runHook postInstallCheck
  '';

  meta = {
    description = "Programmable workspace for coding agents";
    homepage = "https://getbb.app";
    license = pkgs.lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bb-app";
  };
}
