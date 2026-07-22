{
  t,
  customThemePath,
  wallpaper,
}:
{
  configVersion = 12;
  currentThemeName = "custom";
  currentThemeCategory = "generic";
  customThemeFile = customThemePath;
  popupTransparency = t.opacity.overlay;
  cornerRadius = t.radii.lg;

  fontFamily = "FiraCode Nerd Font";
  monoFontFamily = "FiraCode Nerd Font";
  fontScale = 1.0;
  iconThemeDark = "Papirus-Dark";
  iconThemeLight = "Papirus";
  iconThemePerMode = true;
  cursorSettings = {
    theme = "Bibata-Modern-Ice";
    size = 24;
    niri = {
      hideWhenTyping = false;
      hideAfterInactiveMs = 0;
    };
    hyprland = {
      hideOnKeyPress = false;
      hideOnTouch = false;
      inactiveTimeout = 0;
    };
    dwl.cursorHideTimeout = 0;
    mango.cursorHideTimeout = 0;
  };

  blurEnabled = false;
  blurForegroundLayers = true;
  blurBorderEnabled = true;
  blurBorderColor = "custom";
  blurBorderCustomColor = t.colors.border;
  blurBorderOpacity = 0.7;
  gtkThemingEnabled = false;
  qtThemingEnabled = false;
  terminalsAlwaysDark = true;
  runUserMatugenTemplates = false;
  runDmsMatugenTemplates = false;
  matugenTemplateGtk = false;
  matugenTemplateNiri = false;
  matugenTemplateQt5ct = false;
  matugenTemplateQt6ct = false;
  matugenTemplateAlacritty = false;
  matugenTemplateGhostty = false;
  matugenTemplateKitty = false;
  matugenTemplateFoot = false;
  matugenTemplateWezterm = false;
  matugenTemplateDgop = false;

  barConfigs = [
    {
      id = "default";
      name = "Main Bar";
      enabled = true;
      position = 1;
      screenPreferences = [ "all" ];
      showOnLastDisplay = true;
      leftWidgets = [
        "workspaceSwitcher"
        "focusedWindow"
      ];
      centerWidgets = [
        "music"
        "clock"
      ];
      rightWidgets = [
        "systemTray"
        "clipboard"
        "cpuUsage"
        "memUsage"
        "codexUsage"
        "privacyIndicator"
        "notificationButton"
        "controlCenterButton"
      ];
      spacing = t.spacing.sm;
      innerPadding = t.spacing.sm;
      bottomGap = t.spacing.md;
      transparency = t.opacity.panel;
      widgetTransparency = 1.0;
      squareCorners = false;
      noBackground = false;
      borderEnabled = true;
      borderColor = "surfaceText";
      borderOpacity = 1.0;
      borderThickness = 1;
      fontScale = 1.0;
      iconScale = 1.0;
      autoHide = false;
      openOnOverview = false;
      visible = true;
      popupGapsAuto = true;
      popupGapsManual = t.spacing.sm;
      useOverlayLayer = false;
      scrollEnabled = true;
      scrollXBehavior = "column";
      scrollYBehavior = "workspace";
    }
  ];
  showLauncherButton = false;
  showWorkspaceSwitcher = true;
  showFocusedWindow = true;
  showWeather = false;
  weatherEnabled = false;
  showMusic = true;
  showClipboard = true;
  showCpuUsage = true;
  showMemUsage = true;
  showCpuTemp = false;
  showGpuTemp = false;
  showSystemTray = true;
  showClock = true;
  showNotificationButton = true;
  showBattery = false;
  showControlCenterButton = true;
  showPrivacyButton = true;
  privacyShowMicIcon = true;
  privacyShowCameraIcon = true;
  privacyShowScreenShareIcon = true;
  showDock = false;
  dockLauncherEnabled = false;

  launcherStyle = "full";
  launcherUseOverlayLayer = true;
  dankLauncherV2Size = "compact";
  dankLauncherV2ShowFooter = false;
  dankLauncherV2BorderEnabled = true;
  dankLauncherV2BorderThickness = 1;
  dankLauncherV2BorderColor = "primary";
  dankLauncherV2UnloadOnClose = true;
  dankLauncherV2IncludeFilesInAll = false;
  dankLauncherV2IncludeFoldersInAll = false;
  spotlightBarShowModeChips = false;

  controlCenterWidgets = [
    {
      id = "volumeSlider";
      enabled = true;
      width = 50;
    }
    {
      id = "wifi";
      enabled = true;
      width = 50;
    }
    {
      id = "bluetooth";
      enabled = true;
      width = 50;
    }
    {
      id = "audioOutput";
      enabled = true;
      width = 50;
    }
    {
      id = "audioInput";
      enabled = true;
      width = 50;
    }
    {
      id = "nightMode";
      enabled = true;
      width = 50;
    }
  ];
  controlCenterShowNetworkIcon = true;
  controlCenterShowBluetoothIcon = true;
  controlCenterShowAudioIcon = true;
  controlCenterShowAudioPercent = false;
  controlCenterShowVpnIcon = true;
  controlCenterShowBrightnessIcon = false;
  controlCenterShowMicIcon = true;
  controlCenterShowDoNotDisturbIcon = true;

  notificationCompactMode = true;
  notificationOverlayEnabled = false;
  notificationShowTimeoutBar = true;
  notificationDedupeEnabled = true;
  notificationHistoryEnabled = true;
  notificationHistoryMaxCount = 100;
  notificationHistoryMaxAgeDays = 7;
  notificationTimeoutLow = 2000;
  notificationTimeoutNormal = 5000;
  notificationTimeoutCritical = 0;

  clipboardClickToPaste = false;
  clipboardEnterToPaste = true;
  clipboardRememberTypeFilter = true;

  lockPamExternallyManaged = true;
  lockPamPath = "/etc/pam.d/dankshell";
  lockScreenShowPowerActions = false;
  lockScreenShowSystemIcons = true;
  lockScreenShowTime = true;
  lockScreenShowDate = true;
  lockScreenShowProfileImage = true;
  lockScreenShowPasswordField = true;
  lockScreenShowMediaPlayer = false;
  lockScreenPowerOffMonitorsOnLock = false;
  lockScreenNotificationMode = 1;
  lockScreenFontFamily = "FiraCode Nerd Font";
  lockScreenWallpaperPath = wallpaper;
  lockScreenWallpaperFillMode = "Fill";
  loginctlLockIntegration = true;
  lockBeforeSuspend = true;
  fadeToLockEnabled = true;
  fadeToLockGracePeriod = 60;
  fadeToDpmsEnabled = true;
  fadeToDpmsGracePeriod = 5;
  acLockTimeout = 240;
  acMonitorTimeout = 0;
  acPostLockMonitorTimeout = 30;
  acSuspendTimeout = 0;
  batteryLockTimeout = 240;
  batteryMonitorTimeout = 0;
  batteryPostLockMonitorTimeout = 30;
  batterySuspendTimeout = 0;

  wallpaperFillMode = "Fill";
  wallpaperBackgroundColorMode = "black";
  osdAlwaysShowValue = true;
  osdVolumeEnabled = true;
  osdMediaVolumeEnabled = true;
  osdMediaPlaybackEnabled = false;
  osdBrightnessEnabled = true;
  osdMicMuteEnabled = true;
  osdAudioOutputEnabled = true;

  powerActionConfirm = true;
  updaterHideWidget = true;
  updaterCheckOnStart = false;
}
