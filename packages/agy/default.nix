{ pkgs }:
pkgs.stdenv.mkDerivation {
  pname = "antigravity-cli";
  version = "1.5.16";
  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.16-5250855658717184/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha512-Pe6fJuKYFW22c/bOKg9d/tWzAAbgTOuYCcaAcOe3F1h7M6PaD4vC7aRa+BpQvIsUyCsorlgyvP4+f9STlxF7MQ==";
  };
  sourceRoot = ".";
  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];
  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity "$out/bin/agy"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    export HOME="$TMPDIR/agy-home"
    mkdir -p "$HOME"
    "$out/bin/agy" --version
    "$out/bin/agy" acp --help
  '';
  meta = {
    description = "Google Antigravity CLI with ACP support";
    homepage = "https://antigravity.google";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
