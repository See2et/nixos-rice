{ pkgs }:
let
  inherit (pkgs.stdenv) hostPlatform;
  version = "1.5.16";
  release = "${version}-5250855658717184";
  sources = {
    x86_64-linux = {
      archive = "linux-x64/cli_linux_x64.tar.gz";
      hash = "sha512-Pe6fJuKYFW22c/bOKg9d/tWzAAbgTOuYCcaAcOe3F1h7M6PaD4vC7aRa+BpQvIsUyCsorlgyvP4+f9STlxF7MQ==";
    };
    aarch64-darwin = {
      archive = "darwin-arm/cli_mac_arm64.tar.gz";
      hash = "sha256-ukcgL3Et5MSnj9eH2BuiBtc+Ecl1cvxpQg8pp378jZU=";
    };
  };
  source = sources.${hostPlatform.system};
in
pkgs.stdenv.mkDerivation {
  pname = "antigravity-cli";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${release}/${source.archive}";
    inherit (source) hash;
  };
  sourceRoot = ".";
  nativeBuildInputs = pkgs.lib.optionals hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = pkgs.lib.optionals hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];
  # Preserve the upstream macOS code signature.
  dontStrip = hostPlatform.isDarwin;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 antigravity "$out/bin/agy"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/agy-home"
    mkdir -p "$HOME"
    "$out/bin/agy" --version
    "$out/bin/agy" acp --help
    runHook postInstallCheck
  '';
  meta = {
    description = "Google Antigravity CLI with ACP support";
    homepage = "https://antigravity.google";
    license = pkgs.lib.licenses.unfree;
    platforms = builtins.attrNames sources;
    mainProgram = "agy";
  };
}
