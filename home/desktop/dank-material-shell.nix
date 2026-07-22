{
  config,
  dmsPackage,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  t = config.desktop.ui.tokens;
  dms = lib.getExe dmsPackage;
  screenshotDir = "${config.xdg.userDirs.pictures}/Screenshots";
  customThemePath = "${config.xdg.configHome}/DankMaterialShell/themes/see2et-graphite-cyan.json";
  wallpaperDirectory = ../../assets/wallpapers;
  wallpaper = "${wallpaperDirectory}/tori.webp";
  profileImage = ./assets/waybar-logo.png;
  dmsCodexUsagePackage = import ./dms/codex-usage.nix { inherit pkgs; };
  codexUsagePlugin = ./dms/plugins/codex-usage;
  emojiLauncherPlugin = ./dms/plugins/emoji-launcher;
  dmsTheme = import ./dms/theme.nix { inherit t; };
  dmsSettings = import ./dms/settings.nix {
    inherit t customThemePath wallpaper;
  };
  dmsBindings = import ./dms/bindings.nix { inherit dms; };
  dmsServicePath =
    lib.makeBinPath [
      dmsPackage
      config.programs.dank-material-shell.dgop.package
      config.programs.dank-material-shell.quickshell.package
      config.programs.niri.package
      pkgs.bash
      pkgs.coreutils
      pkgs.systemd
      pkgs.networkmanager
      pkgs.glib
      pkgs.wireplumber
      pkgs.brightnessctl
      pkgs.procps
      pkgs.util-linux
      pkgs.iproute2
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.playerctl
      pkgs.libnotify
      dmsCodexUsagePackage
    ]
    + ":${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
  dmsSessionBootstrap = pkgs.writeText "dms-session-bootstrap.json" (
    builtins.toJSON {
      configVersion = 3;
      isLightMode = false;
      wallpaperPath = wallpaper;
      wallpaperCyclingEnabled = true;
      wallpaperCyclingMode = "interval";
      wallpaperCyclingInterval = 1200;
      weatherLocation = "Kanagawa, Japan";
      weatherCoordinates = "35.4478,139.6425";
    }
  );
  dmsScreenshotAll = pkgs.writeShellScriptBin "dms-screenshot-all" ''
    mkdir -p "${screenshotDir}"
    exec ${dms} screenshot all -d "${screenshotDir}"
  '';
  dmsScreenshotRegion = pkgs.writeShellScriptBin "dms-screenshot-region" ''
    mkdir -p "${screenshotDir}"
    exec ${dms} screenshot -d "${screenshotDir}"
  '';
  dmsScreenshotWindow = pkgs.writeShellScriptBin "dms-screenshot-window" ''
    mkdir -p "${screenshotDir}"
    exec ${dms} screenshot window -d "${screenshotDir}"
  '';
  dmsScreenshotFull = pkgs.writeShellScriptBin "dms-screenshot-full" ''
    mkdir -p "${screenshotDir}"
    exec ${dms} screenshot full -d "${screenshotDir}"
  '';
  dmsWallpaperRandom = pkgs.writeShellScriptBin "dms-wallpaper-random" ''
    wallpaper="$(${pkgs.findutils}/bin/find ${wallpaperDirectory} -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 | ${pkgs.coreutils}/bin/shuf -z -n 1 | ${pkgs.coreutils}/bin/tr -d '\0')"
    if [ -z "$wallpaper" ]; then
      printf 'No wallpapers found in %s\n' ${wallpaperDirectory} >&2
      exit 1
    fi
    exec ${dms} ipc call wallpaper set "$wallpaper"
  '';
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  config = lib.mkIf config.programs.niri.enable {
    home.packages = [
      dmsCodexUsagePackage
      dmsScreenshotAll
      dmsScreenshotRegion
      dmsScreenshotWindow
      dmsScreenshotFull
      dmsWallpaperRandom
    ];

    home.activation.dmsSessionBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      session_dir="${config.xdg.stateHome}/DankMaterialShell"
      session_path="$session_dir/session.json"

      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$session_dir"

      if [ ! -e "$session_path" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 ${dmsSessionBootstrap} "$session_path"
      elif [ -n "''${DRY_RUN_CMD:-}" ]; then
        $DRY_RUN_CMD ${pkgs.jq}/bin/jq \
          --arg location "Kanagawa, Japan" \
          --arg coordinates "35.4478,139.6425" \
          '.weatherLocation = $location | .weatherCoordinates = $coordinates' \
          "$session_path"
      else
        session_tmp=""
        trap '${pkgs.coreutils}/bin/rm -f "$session_tmp"' EXIT
        session_tmp="$(${pkgs.coreutils}/bin/mktemp "$session_dir/.session.json.XXXXXX")"
        ${pkgs.jq}/bin/jq \
          --arg location "Kanagawa, Japan" \
          --arg coordinates "35.4478,139.6425" \
          '.weatherLocation = $location | .weatherCoordinates = $coordinates' \
          "$session_path" > "$session_tmp"
        ${pkgs.coreutils}/bin/chmod 0600 "$session_tmp"
        ${pkgs.coreutils}/bin/mv -f "$session_tmp" "$session_path"
        session_tmp=""
        trap - EXIT
      fi
    '';

    home.file.".face".source = profileImage;

    xdg.configFile."DankMaterialShell/themes/see2et-graphite-cyan.json".text = dmsTheme;

    programs.dank-material-shell = {
      enable = true;
      package = dmsPackage;
      systemd.enable = true;
      enableSystemMonitoring = true;
      enableVPN = true;
      enableDynamicTheming = false;
      enableAudioWavelength = false;
      enableCalendarEvents = false;
      managePluginSettings = true;
      plugins = {
        codexUsage = {
          src = codexUsagePlugin;
          settings = { };
        };
        emojiLauncher = {
          src = emojiLauncherPlugin;
          settings = { };
        };
      };

      clipboardSettings = {
        disabled = false;
        maxHistory = 50;
        maxEntrySize = 5242880;
        autoClearDays = 1;
        clearAtStartup = false;
      };

      settings = dmsSettings;
    };

    systemd.user.services.dms.Service.Environment = [
      "PATH=${dmsServicePath}"
      "DMS_DISABLE_MATUGEN=1"
    ];

    programs.niri.settings.binds = dmsBindings;
  };
}
