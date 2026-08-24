{
  config,
  pkgs,
  ...
}:
let
  homeDirectory = config.home.homeDirectory;
  androidSdkRoot = "${homeDirectory}/Android/Sdk";
  androidNdkVersion = "29.0.13846066";
  androidNdkRoot = "${androidSdkRoot}/ndk/${androidNdkVersion}";
  cargoHome = "${homeDirectory}/.cargo";
  rustupHome = "${homeDirectory}/.rustup";

  androidTauriBootstrap = pkgs.writeShellScriptBin "android-tauri-bootstrap" ''
    set -eu

    sdk_root="${androidSdkRoot}"
    ndk_version="${androidNdkVersion}"
    avd_name="tauri-api35"
    image_package="system-images;android-35;google_apis;x86_64"
    cargo_bin_dir="${cargoHome}/bin"
    rustup_bin="$(command -v rustup)"

    mkdir -p "$sdk_root/cmdline-tools/latest" "$ANDROID_AVD_HOME"
    mkdir -p "$cargo_bin_dir"

    for tool in cargo rustc rustdoc cargo-clippy clippy-driver rustfmt; do
      ln -sfn "$rustup_bin" "$cargo_bin_dir/$tool"
    done

    if [ -d "$sdk_root/cmdline-tools/bin" ]; then
      ln -sfn ../bin "$sdk_root/cmdline-tools/latest/bin"
      ln -sfn ../lib "$sdk_root/cmdline-tools/latest/lib"
      [ -e "$sdk_root/cmdline-tools/source.properties" ] && ln -sfn ../source.properties "$sdk_root/cmdline-tools/latest/source.properties"
      [ -e "$sdk_root/cmdline-tools/NOTICE.txt" ] && ln -sfn ../NOTICE.txt "$sdk_root/cmdline-tools/latest/NOTICE.txt"
    fi

    yes | sdkmanager --licenses >/dev/null
    sdkmanager \
      "platform-tools" \
      "emulator" \
      "build-tools;35.0.0" \
      "platforms;android-35" \
      "$image_package" \
      "ndk;$ndk_version"

    rustup toolchain install stable --profile minimal
    rustup default stable
    rustup target add \
      aarch64-linux-android \
      x86_64-linux-android \
      armv7-linux-androideabi \
      i686-linux-android

    avdmanager delete avd -n "$avd_name" >/dev/null 2>&1 || true
    printf 'no\n' | avdmanager create avd --force --name "$avd_name" --package "$image_package"
  '';

  androidStudioLauncher = pkgs.writeShellScriptBin "Android Studio" ''
    export ANDROID_HOME="${androidSdkRoot}"
    export ANDROID_SDK_ROOT="${androidSdkRoot}"
    export ANDROID_USER_HOME="${homeDirectory}/.android"
    export ANDROID_AVD_HOME="${homeDirectory}/.android/avd"
    export NDK_HOME="${androidNdkRoot}"
    export ANDROID_NDK_ROOT="${androidNdkRoot}"
    exec ${pkgs.android-studio}/bin/android-studio "$@"
  '';
in
{
  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
    ANDROID_NDK_ROOT = androidNdkRoot;
    NDK_HOME = androidNdkRoot;
    CARGO_HOME = cargoHome;
    JAVA_HOME = "${pkgs.jdk17_headless}/lib/openjdk";
    ANDROID_USER_HOME = "${homeDirectory}/.android";
    ANDROID_AVD_HOME = "${homeDirectory}/.android/avd";
    RUSTUP_HOME = rustupHome;
  };

  home.sessionPath = [
    "${cargoHome}/bin"
    "${androidSdkRoot}/cmdline-tools/latest/bin"
    "${androidSdkRoot}/platform-tools"
    "${androidSdkRoot}/emulator"
  ];

  home.packages = [
    androidStudioLauncher
    androidTauriBootstrap
  ];
}
