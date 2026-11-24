{
  bb,
  git,
  lib,
  makeWrapper,
  nodejs_24,
  src,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "bb-factory";
  version = "0.1.0-${src.shortRev}";
  inherit src;
  nativeBuildInputs = [
    makeWrapper
    nodejs_24
  ];
  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export PATH="${git}/bin:$PATH"
    export HOME="$TMPDIR/bb-factory-home"
    mkdir -p "$HOME"
    # The adapter fixture creates its executable at runtime inside the sandbox.
    substituteInPlace test/factory.test.js \
      --replace-fail '#!/usr/bin/env node' '#!${nodejs_24}/bin/node'
    node --test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    app="$out/lib/bb-factory"
    skill="$out/share/bb/skills/bb-factory"
    mkdir -p "$app" "$skill" "$out/bin"
    cp -R bin src examples package.json README.md "$app/"
    makeWrapper ${nodejs_24}/bin/node "$out/bin/bb-factory" \
      --add-flags "$app/bin/bb-factory.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          bb
          git
        ]
      }
    substitute skills/bb-factory/SKILL.md "$skill/SKILL.md" \
      --replace-fail "Use this repository's Node CLI; read" 'Read' \
      --replace-fail '../../README.md' "$app/README.md" \
      --replace-fail 'Resolve `../../bin/bb-factory.js` relative' 'Run `bb-factory`' \
      --replace-fail 'to this Skill and invoke its absolute path from' 'from' \
      --replace-fail 'is delivered in place;' 'is managed by Nix;' \
      --replace-fail '../../examples/' "$app/examples/" \
      --replace-fail 'node /absolute/path/bin/bb-factory.js' 'bb-factory'
    runHook postInstall
  '';
}
