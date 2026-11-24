{ pkgs }:
let
  version = "1.8.0";
  sources = {
    x86_64-linux = {
      platform = "linux-x64-gnu";
      hash = "sha256-gOKS/Rva/KXFuEuwjKlRINeSh715E5+LaL0lPeThyDk=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-Rc6iHrXSZR1VFRtu0oXi7mzpJwPv8PwJm4Q1e69rLtY=";
    };
  };
  source = sources.${pkgs.stdenv.hostPlatform.system};
  nativeCli = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-${source.platform}/-/vite-plus-cli-${source.platform}-${version}.tgz";
    inherit (source) hash;
  };
in
pkgs.buildNpmPackage {
  pname = "vite-plus";
  inherit version;
  src = ./.;
  nodejs = pkgs.nodejs_24;
  npmDepsHash = "sha256-J28ptGWEBx/ldsBXxJm55v5bYDj6GZuRdkRHP+gSh70=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;

  nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.stdenv.cc.cc.lib
    pkgs.zlib
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/vite-plus/bin" "$out/bin"
    cp -R node_modules "$out/lib/vite-plus/"
    tar xzf ${nativeCli} --strip-components=1 -C "$out/lib/vite-plus/bin" package/vp
    # Nix supplies the matching JS toolchain; skip the upstream first-run installer.
    touch "$out/lib/vite-plus/bin/.vp-setup-complete"
    for command in vp vpr vpx; do
      if [ "$command" != vp ]; then
        ln -s vp "$out/lib/vite-plus/bin/$command"
      fi
      makeWrapper "$out/lib/vite-plus/bin/$command" "$out/bin/$command" \
        --set VP_ENV_FORBIDDEN 1 \
        --set VP_NO_UPDATE_CHECK 1 \
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nodejs_24 ]}
    done
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/vite-plus-home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_STATE_HOME="$HOME/.local/state"
    mkdir -p "$XDG_CONFIG_HOME/vite-plus" "$TMPDIR/vite-plus-smoke"
    cp ${./config.json} "$XDG_CONFIG_HOME/vite-plus/config.json"
    cd "$TMPDIR/vite-plus-smoke"
    printf '{"name":"vite-plus-smoke","private":true,"type":"module"}\n' > package.json
    "$out/bin/vp" toolchain --global
    "$out/bin/vp" env current
    "$out/bin/vpr" --help
    printf 'const answer: number = 42; console.log(answer);\n' > smoke.ts
    test "$("$out/bin/vpx" ./smoke.ts)" = 42
    "$out/bin/vp" lint smoke.ts
    runHook postInstallCheck
  '';

  meta = {
    description = "Unified web development toolchain from VoidZero";
    homepage = "https://viteplus.dev";
    license = pkgs.lib.licenses.mit;
    mainProgram = "vp";
    platforms = builtins.attrNames sources;
  };
}
