{
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;

  oyasumiVersion = "25.6.12-linux-v0.6.1";
  oyasumiSrc = pkgs.fetchurl {
    url = "https://github.com/sofoxe1/OyasumiVR/releases/download/oyasumivr-v${oyasumiVersion}/oyasumi-linux.tar.zst";
    hash = "sha256-oF8+JIaDNrrn2Y9s57W6cD459xB7FRur+NBkVAIIEHI=";
  };

  oyasumiRuntimeLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    libxkbcommon
    libsoup_3
    nspr
    nss
    openssl
    pango
    webkitgtk_4_1
  ];

  oyasumiRuntimeLibraryPath = pkgs.lib.makeLibraryPath oyasumiRuntimeLibs;
  oyasumiRuntimeBinPath = pkgs.lib.makeBinPath [
    pkgs.desktop-file-utils
    pkgs.xdg-utils
  ];
  oyasumiGSettingsPath = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

  oyasumiBin = pkgs.stdenvNoCC.mkDerivation {
    pname = "oyasumivr-bin";
    version = oyasumiVersion;
    src = oyasumiSrc;

    nativeBuildInputs = [
      pkgs.gnutar
      pkgs.patchelf
      pkgs.zstd
    ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/oyasumi"
      tar --use-compress-program=unzstd -xvf "$src" -C "$out/share/oyasumi"

      if [ -f "$out/share/oyasumi/Oyasumi/OyasumiVR" ]; then
        chmod +x "$out/share/oyasumi/Oyasumi/OyasumiVR"
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}" "$out/share/oyasumi/Oyasumi/OyasumiVR"
      fi

      if [ -f "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar" ]; then
        chmod +x "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar"
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}:\$ORIGIN:\$ORIGIN/cef" "$out/share/oyasumi/Oyasumi/resources/sidecars/oyasumivr-overlay-sidecar"
      fi

      if [ -f "$out/share/oyasumi/Oyasumi/resources/sidecars/cef/libcef.so" ]; then
        patchelf --set-rpath "${oyasumiRuntimeLibraryPath}:\$ORIGIN" "$out/share/oyasumi/Oyasumi/resources/sidecars/cef/libcef.so"
      fi

      runHook postInstall
    '';
  };

  oyasumiLaunch = pkgs.writeShellApplication {
    name = "oyasumivr";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.steam-run
    ];
    text = ''
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
      export __NV_DISABLE_EXPLICIT_SYNC="''${__NV_DISABLE_EXPLICIT_SYNC:-1}"
      export PATH="${oyasumiRuntimeBinPath}:''${PATH}"
      export LD_LIBRARY_PATH="${oyasumiRuntimeLibraryPath}:''${LD_LIBRARY_PATH:-}"
      export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules"
      export GSETTINGS_SCHEMA_DIR="${oyasumiGSettingsPath}"

      steamvr_openxr_manifest="$HOME/.local/share/Steam/steamapps/common/SteamVR/steamxr_linux64.json"

      if [ -z "''${XR_RUNTIME_JSON:-}" ] && [ -f "$steamvr_openxr_manifest" ]; then
        export XR_RUNTIME_JSON="$steamvr_openxr_manifest"
      fi

      exec ${pkgs.steam-run}/bin/steam-run \
        "${oyasumiBin}/share/oyasumi/Oyasumi/OyasumiVR" "$@"
    '';
  };
in
{
  home.packages = lib.optionals isX86_64 [ oyasumiLaunch ];

  xdg.desktopEntries.oyasumivr = lib.mkIf isX86_64 {
    name = "OyasumiVR";
    genericName = "VR Sleep Utilities";
    comment = "Launch OyasumiVR via steam-run";
    exec = "oyasumivr";
    terminal = false;
    categories = [ "Utility" ];
  };
}
