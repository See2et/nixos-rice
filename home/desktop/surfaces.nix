{
  config,
  lib,
  ...
}:
let
  t = config.desktop.ui.tokens;
  stripHash = color: lib.removePrefix "#" color;
in
{
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      "control-center-layer" = "top";
      "layer-shell" = true;
      cssPriority = "application";
      "control-center-width" = 420;
      "notification-window-width" = 420;
      "notification-window-height" = 180;
      "control-center-margin-top" = t.spacing.xxl;
      "control-center-margin-right" = t.spacing.xxl;
      "control-center-margin-bottom" = t.spacing.xxl;
      "control-center-margin-left" = t.spacing.xxl;
      "notification-2fa-action" = true;
      "notification-inline-replies" = false;
      "notification-icon-size" = 48;
      "notification-body-image-height" = 100;
      "notification-body-image-width" = 200;
      "notification-grouping" = true;
      "relative-timestamps" = true;
      "transition-time" = 180;
      "hide-on-clear" = true;
      "hide-on-action" = true;
      timeout = 6;
      "timeout-low" = 2;
      "timeout-critical" = 0;
      fit-to-screen = false;
      "layer-shell-cover-screen" = false;
      "control-center-height" = -1;

      widgets = [
        "title"
        "dnd"
        "volume"
        "backlight"
        "notifications"
      ];

      "widget-config" = {
        title = {
          text = "Inbox";
          "clear-all-button" = true;
          "button-text" = "Clear";
        };
        dnd.text = "Focus";
        volume = {
          label = "Volume";
          "show-per-app" = false;
        };
        backlight = {
          label = "Brightness";
          device = "intel_backlight";
        };
        notifications.vexpand = true;
      };

      "notification-visibility" = {
        "desktop-osd-volume" = {
          state = "transient";
          "app-name" = "^desktop-osd$";
          summary = "^Volume$";
          "override-urgency" = "low";
        };
        "desktop-osd-brightness" = {
          state = "transient";
          "app-name" = "^desktop-osd$";
          summary = "^Brightness$";
          "override-urgency" = "low";
        };
      };
    };

    style = lib.mkForce ''
      * {
        font-family: ${t.typography.family};
        font-size: ${toString t.typography.size.md}px;
      }

      .floating-notifications {
        background: transparent;
      }

      blankwindow,
      .blank-window,
      #control-center-window {
        background: transparent;
      }

      .control-center {
        background: alpha(${t.colors.background}, ${toString t.opacity.overlay});
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.lg}px;
        box-shadow: 0 12px 32px rgba(0, 0, 0, 0.4);
      }

      .control-center .control-center-list {
        padding: ${toString t.spacing.sm}px;
      }

      .control-center .control-center-list-placeholder {
        color: ${t.colors.muted};
      }

      .notification {
        background: ${t.colors.surface};
        color: ${t.colors.foreground};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.md}px;
        margin: ${toString t.spacing.md}px ${toString t.spacing.xxl}px;
        padding: ${toString t.spacing.sm}px;
      }

      .notification .notification-default-action {
        border-radius: ${toString t.radii.md}px;
      }

      .notification .notification-default-action .summary {
        font-size: ${toString t.typography.size.md}px;
      }

      .notification .notification-default-action .body {
        color: ${t.colors.muted};
      }

      .notification.critical {
        border-color: ${t.colors.danger};
      }

      .notification-row:focus,
      .notification-row:hover {
        background: ${t.colors.surfaceElevated};
      }

      .notification progressbar trough {
        background: ${t.colors.surfaceElevated};
        border-radius: ${toString t.radii.pill}px;
        min-height: 6px;
      }

      .notification progressbar progress {
        background: ${t.colors.accent};
        border-radius: ${toString t.radii.pill}px;
      }

      .widget-title,
      .widget-dnd,
      .widget-mpris,
      .widget-volume,
      .widget-backlight {
        background: ${t.colors.surface};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.md}px;
      }

      .widget-title button,
      .widget-dnd switch,
      .widget-volume button,
      .widget-backlight button {
        border-radius: ${toString t.radii.sm}px;
      }

      .widget-volume scale trough,
      .widget-backlight scale trough {
        min-height: 6px;
        border-radius: ${toString t.radii.pill}px;
        background: ${t.colors.surfaceElevated};
      }

      .widget-volume scale highlight,
      .widget-backlight scale highlight {
        border-radius: ${toString t.radii.pill}px;
        background: ${t.colors.accent};
      }
    '';
  };

  programs.swaylock = {
    enable = true;
    settings = lib.mkForce {
      daemonize = true;
      clock = true;
      effect-blur = "${toString t.blur.overlay}x${toString t.blur.overlay}";
      effect-vignette = "0.25:0.25";
      fade-in = 0.2;

      color = stripHash t.colors.overlay;
      text-color = stripHash t.colors.foreground;
      inside-color = stripHash t.colors.transparent;
      inside-clear-color = stripHash t.colors.transparent;
      inside-ver-color = stripHash t.colors.transparent;
      inside-wrong-color = stripHash t.colors.transparent;
      line-color = stripHash t.colors.transparent;
      separator-color = stripHash t.colors.transparent;
      ring-color = stripHash t.colors.border;
      ring-clear-color = stripHash t.colors.warning;
      ring-ver-color = stripHash t.colors.success;
      ring-wrong-color = stripHash t.colors.danger;
      key-hl-color = stripHash t.colors.accent;
      bs-hl-color = stripHash t.colors.warning;

      indicator = true;
      indicator-radius = t.sizes.lockIndicatorRadius;
      indicator-thickness = t.sizes.lockIndicatorThickness;

      font = t.typography.family;
      font-size = t.typography.size.lg;
      show-failed-attempts = true;
      ignore-empty-password = true;
    };
  };

  programs.wlogout = {
    enable = true;

    layout = [
      {
        label = "lock";
        action = "desktop-session-action lock";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "desktop-session-action logout";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "desktop-session-action suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "desktop-session-action reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "desktop-session-action shutdown";
        text = "Shutdown";
        keybind = "s";
      }
    ];

    style = ''
      * {
        background-image: none;
        box-shadow: none;
        font-family: ${t.typography.family};
      }

      window {
        background: alpha(${t.colors.background}, ${toString t.opacity.overlay});
      }

      button {
        color: ${t.colors.foreground};
        background-color: ${t.colors.surface};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.md}px;
        margin: ${toString t.spacing.lg}px;
        padding: ${toString t.spacing.xxl}px;
        font-size: ${toString t.typography.size.lg}px;
      }

      button:hover,
      button:focus {
        background-color: ${t.colors.accent};
        color: ${t.colors.background};
        border-color: ${t.colors.accent};
      }

      #shutdown {
        border-color: ${t.colors.danger};
      }
    '';
  };
}
