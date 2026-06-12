{ pkgs }:

pkgs.buildNpmPackage {
  pname = "pencil-cli";
  version = "0.2.7";

  src = ./.;
  npmDepsHash = "sha256-mM3ZB5kzh0ZCpZOA52jPVsDjmhRDiuZUVZOhtDGDRqI=";

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/pencil-cli $out/bin
    cp -R node_modules package.json package-lock.json $out/lib/pencil-cli/
    makeWrapper ${pkgs.nodejs_24}/bin/node $out/bin/pencil \
      --add-flags $out/lib/pencil-cli/node_modules/@pencil.dev/cli/dist/index.mjs
    runHook postInstall
  '';

  meta = {
    description = "CLI tool for running the Pencil AI agent manipulating .pen design files";
    homepage = "https://docs.pencil.dev/for-developers/pencil-cli";
    license = pkgs.lib.licenses.unfree;
    mainProgram = "pencil";
  };
}
