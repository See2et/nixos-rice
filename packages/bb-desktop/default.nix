{ pkgs }:
let
  version = "0.50.1";
  pname = "bb-desktop";
in
if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.stdenvNoCC.mkDerivation {
    inherit pname version;
    src = pkgs.fetchurl {
      url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-arm64.zip";
      sha256 = "5e6275ddc46a91ebb80dd4a9bf7c0273fa97552d5d1984d9c8c43b3da446460c";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    sourceRoot = ".";
    dontFixup = true;
    installPhase = ''
      mkdir -p "$out/share" "$out/Applications/bb.app/Contents/MacOS"
      # Keep the signed upstream bundle intact; Finder launches a small Nix-owned wrapper.
      cp -R bb.app "$out/share/"
      ln -s "$out/share/bb.app/Contents/Resources" "$out/Applications/bb.app/Contents/Resources"
      cat > "$out/Applications/bb.app/Contents/Info.plist" <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>bb-client</string>
        <key>CFBundleIdentifier</key><string>app.getbb.nix-client</string>
        <key>CFBundleName</key><string>bb</string>
        <key>CFBundleIconFile</key><string>icon.icns</string>
        <key>CFBundlePackageType</key><string>APPL</string>
      </dict></plist>
      EOF
      cat > "$out/Applications/bb.app/Contents/MacOS/bb-client" <<EOF
      #!/bin/sh
      export BB_DESKTOP_AUTO_UPDATE=0
      exec "$out/share/bb.app/Contents/MacOS/bb" "\$@"
      EOF
      chmod +x "$out/Applications/bb.app/Contents/MacOS/bb-client"
    '';
    meta = {
      description = "bb desktop client (choose a remote server in the Server menu)";
      homepage = "https://getbb.app";
      license = pkgs.lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
    };
  }
else
  pkgs.appimageTools.wrapType2 {
    inherit pname version;
    src = pkgs.fetchurl {
      url = "https://github.com/get-bb/bb/releases/download/desktop-v${version}/bb-${version}-x86_64.AppImage";
      sha256 = "7063d187817abaff710afaba039bed78923e464a9006a39231ff04d1764408a8";
    };
    extraInstallCommands = ''
      mv "$out/bin/bb-desktop" "$out/bin/.bb-desktop"
      cat > "$out/bin/bb-desktop" <<EOF
      #!${pkgs.runtimeShell}
      export BB_DESKTOP_AUTO_UPDATE=0
      exec "$out/bin/.bb-desktop" "\$@"
      EOF
      chmod +x "$out/bin/bb-desktop"
      mkdir -p "$out/share/applications"
      cat > "$out/share/applications/bb.desktop" <<EOF
      [Desktop Entry]
      Type=Application
      Name=bb
      Comment=bb desktop client
      Exec=$out/bin/bb-desktop %U
      Terminal=false
      Categories=Development;
      EOF
    '';
    meta = {
      description = "bb desktop client (Linux alpha)";
      homepage = "https://getbb.app";
      license = pkgs.lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "bb-desktop";
    };
  }
