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
      "control-center-margin-top" = t.spacing.xxl;
      "control-center-margin-right" = t.spacing.xxl;
      "control-center-margin-bottom" = t.spacing.xxl;
      "control-center-margin-left" = t.spacing.xxl;
      "notification-2fa-action" = true;
      "notification-inline-replies" = false;
      "notification-icon-size" = 48;
      "notification-body-image-height" = 100;
      "notification-body-image-width" = 200;
      timeout = 6;
      "timeout-low" = 3;
      "timeout-critical" = 0;
      fit-to-screen = true;
    };

    style = lib.mkForce ''
      * {
        font-family: ${t.typography.family};
        font-size: ${toString t.typography.size.md}px;
      }

      .control-center {
        background: alpha(${t.colors.background}, ${toString t.opacity.overlay});
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.lg}px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
      }

      .notification {
        background: ${t.colors.surface};
        color: ${t.colors.foreground};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.md}px;
        margin: ${toString t.spacing.md}px ${toString t.spacing.xxl}px;
        padding: ${toString t.spacing.md}px;
      }

      .notification.critical {
        border-color: ${t.colors.danger};
      }

      .notification-row:focus,
      .notification-row:hover {
        background: ${t.colors.surfaceElevated};
      }

      .widget-title,
      .widget-dnd,
      .widget-mpris,
      .widget-volume,
      .widget-backlight {
        border-radius: ${toString t.radii.md}px;
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
        action = "swaylock -f";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "niri msg action quit";
        text = "Logout";
        keybind = "e";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Suspend";
        keybind = "u";
      }
      {
        label = "reboot";
        action = "systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "systemctl poweroff";
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
