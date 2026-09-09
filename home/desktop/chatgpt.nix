{ pkgs }:
let
  launcher = pkgs.writeShellApplication {
    name = "chatgpt-launcher";
    text = ''
      # Electron copies plugin files preserving modes, then rewrites manifests.
      # A writable source prevents Nix store modes from breaking that operation.
      cacheRoot="''${XDG_CACHE_HOME:-$HOME/.cache}/chatgpt/bundled-plugins"
      resourcesPath="$cacheRoot/$(basename "$CHATGPT_PACKAGE")"
      if [[ ! -f "$resourcesPath/.complete" ]]; then
        mkdir -p "$cacheRoot"
        stagingPath=$(mktemp -d "$cacheRoot/.staging.XXXXXXXX")
        trap 'rm -rf -- "$stagingPath"' EXIT
        ln -s "$CHATGPT_PACKAGE/lib/chatgpt/resources/"{codex,codex-code-mode-host,cua_node,native,rg} "$stagingPath/"
        cp -R "$CHATGPT_PACKAGE/lib/chatgpt/resources/plugins" "$stagingPath/plugins"
        chmod -R u+w "$stagingPath/plugins"
        touch "$stagingPath/.complete"
        if mv -T "$stagingPath" "$resourcesPath" 2>/dev/null; then
          trap - EXIT
        elif [[ -f "$resourcesPath/.complete" ]]; then
          rm -rf -- "$stagingPath"
          trap - EXIT
        else
          exit 1
        fi
      fi
      export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$resourcesPath"
      # Keep the vendor's XWayland default; --ozone-platform=wayland is opt-in.
      exec "$CHATGPT_PACKAGE/lib/chatgpt/ChatGPT" "$@"
    '';
  };
in
pkgs.stdenv.mkDerivation rec {
  pname = "chatgpt";
  version = "26.903.61454";

  # Official Linux preview. Update version and hash together from the apt index:
  # https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages
  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
    hash = "sha256-LKp98xTON+kEg1nY5qSnjiRXSjtU1r9RDxd1S2bdp3U=";
  };

  nativeBuildInputs = with pkgs; [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
    python3
  ];

  buildInputs = with pkgs; [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libGL
    libdrm
    libgbm
    libusb1
    libxkbcommon
    nspr
    nss
    openssl
    pango
    stdenv.cc.cc.lib
    systemdLibs
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  runtimeDependencies = with pkgs; [
    (lib.getLib libGL)
    (lib.getLib libnotify)
    (lib.getLib libpulseaudio)
    (lib.getLib libsecret)
    (lib.getLib pipewire)
    (lib.getLib systemdLibs)
    (lib.getLib vulkan-loader)
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar -x
    runHook postUnpack
  '';

  dontBuild = true;
  dontWrapGApps = true;
  # Preserve bundled native modules and the vendor runtime.
  dontStrip = true;

  postPatch = ''
    # autoPatchelf moves PT_INTERP past detect-libc's 2 KiB scan. Its fallback
    # crashes this Electron runtime's CFI when loading the repository watcher.
    # Keep the replacement byte-for-byte the same size to preserve asar offsets.
    python3 - <<'PY'
    from pathlib import Path
    archive = Path("usr/lib/chatgpt/resources/app.asar")
    data = archive.read_bytes()
    old = b"const family = familySync();"
    new = b"const family = 'glibc'     ;"
    assert old in data and len(old) == len(new)
    archive.write_bytes(data.replace(old, new))
    PY
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin" "$out/share"
    cp -a usr/lib/chatgpt "$out/lib/"
    cp -a usr/share/applications usr/share/pixmaps "$out/share/"

    # Use GTK on this desktop; optional Qt shims are not needed.
    rm "$out/lib/chatgpt/libqt5_shim.so" "$out/lib/chatgpt/libqt6_shim.so"
    # The deb includes alternative musl prebuilds, unused on NixOS/glibc.
    find "$out/lib/chatgpt/resources" -type f \
      \( -name '*.musl.node' -o -path '*-musl/*.node' \) -delete

    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U"
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper ${pkgs.lib.getExe launcher} "$out/bin/chatgpt" \
      "''${gappsWrapperArgs[@]}" \
      --set CHATGPT_PACKAGE "$out" \
      --suffix PATH : ${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}
  '';

  meta = {
    description = "Official ChatGPT desktop application for Linux (preview)";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = pkgs.lib.licenses.unfree;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
