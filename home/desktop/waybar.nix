{ config, ... }:
let
  logoIcon = ./assets/waybar-logo.png;
  t = config.desktop.ui.tokens;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      button,
      button:hover {
        box-shadow: none;
      }

      window#waybar {
        color: ${t.colors.foreground};
        background-color: transparent;
        font-family: ${t.typography.family};
        font-size: ${toString t.typography.size.md}px;
        font-style: normal;
        min-height: 0;
      }

      window#waybar > box {
        background-color: ${t.colors.background};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.lg}px;
      }

      #workspaces,
      .modules-right box {
        background-color: ${t.colors.surface};
        margin: 0 ${toString t.spacing.sm}px;
        padding: ${toString t.spacing.xs}px ${toString t.spacing.sm}px;
        border-radius: ${toString t.radii.lg}px;
      }

      .modules-right label.module {
        margin: 0 ${toString t.spacing.lg}px;
      }

      .modules-left #image {
        margin: 0 ${toString t.spacing.lg}px;
      }

      .modules-right box {
        padding: ${toString t.spacing.xs}px ${toString t.spacing.md}px;
      }

      .modules-left,
      .modules-right {
        margin: ${toString t.spacing.md}px ${toString t.spacing.lg}px;
      }

      #workspaces {
        background-color: ${t.colors.surface};
        padding: 0;
      }

      #workspaces button {
        background-color: transparent;
        color: ${t.colors.foreground};
        padding: 0 ${toString t.spacing.md}px;
        transition: none;
      }

      #workspaces button:nth-child(1) {
        border-top-left-radius: ${toString t.radii.lg}px;
        border-bottom-left-radius: ${toString t.radii.lg}px;
      }

      #workspaces button:nth-last-child(1) {
        border-top-right-radius: ${toString t.radii.lg}px;
        border-bottom-right-radius: ${toString t.radii.lg}px;
      }

      #workspaces button.empty {
        color: ${t.colors.muted};
      }

      #workspaces button.visible {
        background: ${t.colors.surfaceElevated};
      }

      #workspaces button.focused {
        box-shadow: none;
      }

      #workspaces button.active {
        background: ${t.colors.accent};
        color: ${t.colors.background};
      }

      #workspaces button:hover {
        background: ${t.colors.surfaceElevated};
        color: ${t.colors.foreground};
        box-shadow: none;
      }

      #workspaces button.active:hover {
        background: ${t.colors.accent};
        color: ${t.colors.background};
      }

      #workspaces button.urgent {
        background: ${t.colors.danger};
        color: ${t.colors.background};
      }

      #window {
        background: transparent;
      }

      window#waybar.floating #window {
        color: ${t.colors.accent};
      }

      #clock {
        color: ${t.colors.lavender};
      }

      #power-profiles-daemon {
        color: ${t.colors.info};
      }

      #custom-codex {
        color: ${t.colors.info};
        font-family: ${t.typography.monoFamily};
      }

      #custom-codex.warning {
        color: ${t.colors.warning};
      }

      #custom-codex.critical {
        color: ${t.colors.danger};
      }

      #battery {
        color: ${t.colors.success};
      }

      #battery.charging {
        color: ${t.colors.success};
      }

      #battery.warning:not(.charging) {
        color: ${t.colors.warning};
      }

      #battery.critical:not(.charging) {
        color: ${t.colors.danger};
      }

      #backlight {
        color: ${t.colors.warning};
      }

      #pulseaudio {
        color: ${t.colors.accent};
        font-family: ${t.typography.iconFamily};
      }

      #custom-notifications {
        margin: 0;
        min-width: 1.8em;
        font-family: ${t.typography.iconFamily};
      }

      #custom-notifications.none,
      #custom-notifications.inhibited-none {
        color: ${t.colors.foreground};
      }

      #custom-notifications.notification,
      #custom-notifications.inhibited-notification {
        color: ${t.colors.warning};
      }

      #custom-notifications.dnd-none,
      #custom-notifications.dnd-inhibited-none {
        color: ${t.colors.muted};
      }

      #custom-notifications.dnd-notification,
      #custom-notifications.dnd-inhibited-notification {
        color: ${t.colors.warning};
      }

      #custom-power {
        color: ${t.colors.danger};
      }

      #privacy {
        margin: 0 ${toString t.spacing.sm}px;
        padding: 0;
      }

      #privacy-item {
        padding: 0 1px;
        color: ${t.colors.foreground};
      }

      tooltip {
        background: ${t.colors.background};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.sm}px;
      }

      tooltip * {
        padding: 0;
        margin: 0;
        color: ${t.colors.foreground};
        font-family: ${t.typography.monoFamily};
      }
    '';
    settings = [
      {
        layer = "top";
        position = "bottom";
        height = t.sizes.barHeight;
        "margin-top" = t.spacing.md;
        "margin-left" = t.spacing.md;
        "margin-right" = t.spacing.md;
        "margin-bottom" = t.spacing.md;

        "modules-left" = [
          "image#logo"
          "niri/workspaces"
          "niri/window"
        ];
        "modules-center" = [ "clock" ];
        "modules-right" = [
          "group/playback"
          "group/status"
          "group/notifications"
          "tray"
          "group/power"
        ];

        "group/playback" = {
          orientation = "inherit";
          modules = [ "custom/music" ];
        };

        "group/status" = {
          orientation = "inherit";
          modules = [
            "pulseaudio"
            "backlight"
            "battery"
            "power-profiles-daemon"
            "custom/codex"
          ];
        };

        "group/power" = {
          orientation = "inherit";
          modules = [
            "custom/lock"
            "custom/power"
          ];
        };

        "group/notifications" = {
          orientation = "inherit";
          modules = [ "custom/notifications" ];
        };

        "image#logo" = {
          path = logoIcon;
          size = t.sizes.barLogo;
          tooltip = false;
          interval = 0;
        };

        "niri/workspaces" = {
          format = "{icon}";
          "format-icons" = {
            active = "";
            focused = "";
            empty = "";
            default = "";
          };
        };

        "niri/window" = {
          format = "{}";
          icon = true;
          "icon-size" = 16;
          rewrite = {
            "(.*) - Vivaldi" = "$1";
            "(.*) - Visual Studio Code" = "$1";
            "(\\S+\\.js\\s.*)" = " $1";
            "(\\S+\\.ts\\s.*)" = " $1";
            "(\\S+\\.go\\s.*)" = " $1";
            "(\\S+\\.lua\\s.*)" = " $1";
            "(\\S+\\.java\\s.*)" = " $1";
            "(\\S+\\.rb\\s.*)" = " $1";
            "(\\S+\\.php\\s.*)" = " $1";
            "(\\S+\\.jsonc?\\s.*)" = " $1";
            "(\\S+\\.md\\s.*)" = " $1";
            "(\\S+\\.txt\\s.*)" = " $1";
            "(\\S+\\.cs\\s.*)" = " $1";
            "(\\S+\\.c\\s.*)" = " $1";
            "(\\S+\\.cpp\\s.*)" = " $1";
            "(\\S+\\.hs\\s.*)" = " $1";
            ".*Discord | (.*) | .*" = "$1 - ArmCord";
          };
          "separate-outputs" = true;
        };

        tray = {
          "icon-size" = t.sizes.trayIcon;
          spacing = t.spacing.sm;
        };

        "custom/notifications" = {
          "return-type" = "json";
          exec = "swaync-client -swb";
          format = "{icon}";
          "format-icons" = {
            notification = " ";
            none = "";
            "dnd-notification" = " ";
            "dnd-none" = "";
            "inhibited-notification" = " ";
            "inhibited-none" = "";
            "dnd-inhibited-notification" = " ";
            "dnd-inhibited-none" = "";
          };
          tooltip = true;
          escape = true;
          "on-click" = "swaync-client -t -sw";
          "on-click-right" = "swaync-client -d -sw";
        };

        "custom/music" = {
          format = "♫ {}";
          escape = true;
          interval = 5;
          tooltip = false;
          exec = "playerctl metadata --format='{{ title }}'";
          "on-click" = "playerctl play-pause";
          "max-length" = 50;
        };

        clock = {
          timezone = "Asia/Tokyo";
          format = "{:%H:%M}";
          "format-alt" = "{:%a %b %d %R}";
          "tooltip-format" = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            "mode-mon-col" = 3;
            "weeks-pos" = "right";
            "on-scroll" = 1;
            "on-click-right" = "mode";
            format = {
              months = "<span color='${t.colors.foreground}'><b>{}</b></span>";
              days = "<span color='${t.colors.accent}'><b>{}</b></span>";
              weeks = "<span color='${t.colors.info}'><b>W{}</b></span>";
              weekdays = "<span color='${t.colors.warning}'><b>{}</b></span>";
              today = "<span color='${t.colors.danger}'><b><u>{}</u></b></span>";
            };
            actions = {
              "on-click-right" = "mode";
              "on-click-forward" = "tz_up";
              "on-click-backward" = "tz_down";
              "on-scroll-up" = "shift_up";
              "on-scroll-down" = "shift_down";
            };
          };
        };

        backlight = {
          device = "intel_backlight";
          format = "{icon} {percent}%";
          "format-icons" = [
            ""
            ""
          ];
          "scroll-step" = 1;
        };

        battery = {
          interval = 30;
          states = {
            warning = 20;
            critical = 10;
          };
          "full-at" = 98;
          format = "{icon} {capacity}%";
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
          ];
          "format-critical" = " {capacity}%";
          "tooltip-format" = "{timeTo} ({power}W)";
          "format-charging" = " {capacity}%";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          "format-bluetooth" = "{icon} {volume}%";
          "format-muted" = " {volume}%";
          "format-icons" = {
            headphone = "";
            "hands-free" = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          "scroll-step" = 1;
          "on-click" = "pavucontrol";
          "ignored-sinks" = [ "Easy Effects Sink" ];
        };

        privacy = {
          "icon-spacing" = 0;
          "icon-size" = t.sizes.privacyIcon;
          "transition-duration" = 250;
          modules = [
            { type = "screenshare"; }
            { type = "audio-in"; }
          ];
        };

        "power-profiles-daemon" = {
          format = "{icon}";
          tooltip = true;
          "tooltip-format" = "Power profile: {profile}\nDriver: {driver}";
          "format-icons" = {
            default = "";
            performance = " perf";
            balanced = " balance";
            "power-saver" = " save";
          };
        };

        "custom/codex" = {
          "return-type" = "json";
          interval = 30;
          format = "{}";
          exec = ''
            python3 - <<'PY'
            import json
            from pathlib import Path
            from urllib import error, request

            def emit(payload):
                print(json.dumps(payload))

            def normalize_percent(value):
                if 0.0 <= value <= 1.0:
                    value *= 100.0
                value = max(0.0, min(100.0, value))
                return int(round(value))

            def extract_windows(rate_limit):
                if not isinstance(rate_limit, dict):
                    return None, None

                windows = []
                for key in ("primary_window", "secondary_window", "primary", "secondary"):
                    candidate = rate_limit.get(key)
                    if isinstance(candidate, dict):
                        windows.append(candidate)

                five_hour = None
                weekly = None
                for window in windows:
                    raw_pct = window.get("used_percent")
                    raw_seconds = window.get("limit_window_seconds")
                    raw_minutes = window.get("window_minutes")

                    if not isinstance(raw_pct, (int, float)):
                        continue

                    minutes = None
                    if isinstance(raw_seconds, (int, float)):
                        minutes = int(round(float(raw_seconds) / 60.0))
                    elif isinstance(raw_minutes, (int, float)):
                        minutes = int(round(float(raw_minutes)))

                    if minutes == 300:
                        five_hour = float(raw_pct)
                    elif minutes == 10080:
                        weekly = float(raw_pct)

                return five_hour, weekly

            def fetch_live_limits():
                auth_path = Path.home() / ".codex" / "auth.json"
                try:
                    auth = json.loads(auth_path.read_text(encoding="utf-8"))
                except OSError:
                    return None, None, "Codex auth not found"
                except json.JSONDecodeError:
                    return None, None, "Codex auth is invalid"

                tokens = auth.get("tokens") if isinstance(auth, dict) else None
                if not isinstance(tokens, dict):
                    return None, None, "Codex tokens unavailable"

                access_token = tokens.get("access_token")
                account_id = tokens.get("account_id")
                if not isinstance(access_token, str) or not access_token:
                    return None, None, "Codex access token missing"

                req = request.Request("https://chatgpt.com/backend-api/wham/usage")
                req.add_header("Authorization", f"Bearer {access_token}")
                req.add_header("User-Agent", "codex-cli")
                req.add_header("Accept", "application/json")
                if isinstance(account_id, str) and account_id:
                    req.add_header("ChatGPT-Account-Id", account_id)

                try:
                    with request.urlopen(req, timeout=12) as response:
                        payload = json.loads(response.read().decode("utf-8", "replace"))
                except error.HTTPError as exc:
                    return None, None, f"Codex API HTTP {exc.code}"
                except error.URLError:
                    return None, None, "Codex API unreachable"
                except json.JSONDecodeError:
                    return None, None, "Codex API returned invalid JSON"

                rate_limit = payload.get("rate_limit") if isinstance(payload, dict) else None
                five_hour, weekly = extract_windows(rate_limit)
                if five_hour is None or weekly is None:
                    return None, None, "Codex API missing rate limits"

                return five_hour, weekly, "live"

            five_hour, weekly, status = fetch_live_limits()
            if five_hour is None or weekly is None:
                emit({"text": "󰚩 --/--", "tooltip": status})
                raise SystemExit(0)

            five_hour_used_pct = normalize_percent(five_hour)
            weekly_used_pct = normalize_percent(weekly)
            five_hour_pct = max(0, 100 - five_hour_used_pct)
            weekly_pct = max(0, 100 - weekly_used_pct)

            severity = ""
            lowest_remaining = min(five_hour_pct, weekly_pct)
            if lowest_remaining <= 5:
                severity = "critical"
            elif lowest_remaining <= 20:
                severity = "warning"

            emit(
                {
                    "text": f"󰚩 {five_hour_pct}%/{weekly_pct}%",
                    "tooltip": f"5h limit: {five_hour_pct}%\\nWeekly limit: {weekly_pct}%",
                    "class": severity,
                }
            )
            PY
          '';
          tooltip = true;
        };

        "custom/lock" = {
          tooltip = false;
          "on-click" = "desktop-lock";
          format = "";
        };

        "custom/power" = {
          tooltip = true;
          "tooltip-format" = "Power menu";
          "on-click" = "desktop-power-menu";
          format = "⏻";
        };
      }
    ];
  };

  catppuccin.waybar.enable = false;
}
