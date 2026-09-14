{
  lib,
  pkgs,
  inputs,
  hostId,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  typstPreviewCompat = pkgs.writeShellScriptBin "typst-preview" ''
    exec ${pkgs.tinymist}/bin/tinymist preview "$@"
  '';

  mkAnkiAddonFromRelease =
    {
      addonName,
      version,
      url,
      hash,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "anki-addon-${addonName}";
      inherit version;
      src = pkgs.fetchurl {
        inherit url hash;
      };
      dontUnpack = true;
      installPhase = ''
        runHook preInstall

        addonDir="$out/share/anki/addons/${addonName}"
        mkdir -p "$addonDir"
        ${pkgs.unzip}/bin/unzip -qq "$src" -d "$addonDir"
        mkdir -p "$addonDir/user_files"

        # Runtime compatibility patches for legacy add-ons on Anki 25 / Python 3.13 / Qt6.
        # Keep this section surgical: only patch known crash points from real tracebacks.
        case "${addonName}" in
          awesome-tts)
            # Avoid writes to /nix/store by redirecting runtime cache/log/config to user data dir.
            if [ -f "$addonDir/awesometts/paths.py" ]; then
              substituteInPlace "$addonDir/awesometts/paths.py" \
                --replace-fail "USER_FILES = os.path.join(ROOT, 'user_files')" "USER_FILES = os.environ.get('AWESOMETTS_USER_FILES', os.path.join(os.path.expanduser('~'), '.local', 'share', 'Anki2', 'addons21', 'awesome-tts', 'user_files'))" \
                --replace-fail "LOG = os.path.join(ADDON, 'addon.log')" "LOG = os.path.join(USER_FILES, 'addon.log')"
            fi

            # Guard against missing addon config metadata during first-run initialization.
            if [ -f "$addonDir/awesometts/__init__.py" ]; then
              substituteInPlace "$addonDir/awesometts/__init__.py" \
                --replace-fail 'addon_config = aqt.mw.addonManager.getConfig(CONFIG_ADDON_NAME)' 'addon_config = aqt.mw.addonManager.getConfig(CONFIG_ADDON_NAME) or {}' \
                --replace-fail 'aqt.mw.addonManager.writeConfig(CONFIG_ADDON_NAME, addon_config)' 'pass'
            fi
            ;;
        esac

        runHook postInstall
      '';
    };

  ankiAddonAwesomeTTS = mkAnkiAddonFromRelease {
    addonName = "awesome-tts";
    version = "1.89.4";
    url = "https://github.com/Vocab-Apps/anki-awesome-tts/releases/download/v1.89.4/anki-awesome-tts-1.89.4.ankiaddon";
    hash = "sha256-IMxL6duwdMT0949fqLbX6bTN2NIwNsCMG5aaizlj0AM=";
  };

  ankiAddonHitmarkers = mkAnkiAddonFromRelease {
    addonName = "hitmarkers";
    version = "0.2.0";
    url = "https://github.com/glutanimate/hitmarkers/releases/download/v0.2.0/hitmarkers-v0.2.0-qt5+qt6.ankiaddon";
    hash = "sha256-1jTsaPgjTeQfTxzz3H5axkpxT/ITggNxYfMy1hIOeE0=";
  };

  ankiAddonReviewHeatmap = pkgs.ankiAddons."review-heatmap";

  ankiWithRequestedAddons = pkgs.anki.withAddons [
    ankiAddonAwesomeTTS
    ankiAddonHitmarkers
    ankiAddonReviewHeatmap
  ];

  pearDesktopPatched = pkgs.pear-desktop.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/pear-desktop-window-lifecycle.patch
    ];
  });

in
{
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  xdg.dataFile."applications/slack.desktop" = lib.mkIf isX86_64 {
    text = ''
      [Desktop Entry]
      Name=Slack
      StartupWMClass=Slack
      Comment=Slack Desktop
      GenericName=Slack Client for Linux
      Exec=${lib.getExe pkgs.slack} --disable-gpu %U
      Icon=slack
      Type=Application
      Terminal=false
      StartupNotify=true
      Categories=GNOME;GTK;Network;InstantMessaging;
      MimeType=x-scheme-handler/slack;
    '';
  };

  home.packages =
    (with pkgs; [
      alacritty
      ghostty
      kitty
      wezterm
      btop
      htop
      tinymist
      websocat
      typstPreviewCompat
      grim
      slurp
      xwayland-satellite
      wl-clipboard
      playerctl
      swayimg
      mpv
      pavucontrol
      pulseaudio
      brightnessctl
      gcolor3
      pkgsUnstable.godot_4_6
      ankiWithRequestedAddons
      pkgsUnstable.obsidian
      obs-studio
      thunar
      thunar-archive-plugin
      thunar-volman
      p7zip
    ])
    ++ lib.optionals isX86_64 (
      with pkgs;
      [
        google-chrome
        pkgsUnstable.discord
        pkgsUnstable.discord-canary
        slack
        zoom-us
        figma-linux
        pearDesktopPatched
        yubioath-flutter
      ]
    )
    ++ lib.optionals (hostId == "desktop") [
      (import ./chatgpt.nix { inherit pkgs; })
      pkgs.bambu-studio
      pkgsUnstable.zmk-studio
    ];
}
