{ pkgs }:
pkgs.writeShellApplication {
  name = "dms-codex-usage";
  runtimeInputs = [ pkgs.python3 ];
  text = ''
    exec python3 - <<'PY' "$@"
    import json
    import os
    import sys
    from datetime import datetime
    from pathlib import Path
    from urllib import error, request


    MODE_USAGE = "usage"
    MODE_RESET = "reset"


    class NoRedirectHandler(request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None


    def cache_dir() -> Path:
        base = os.environ.get("XDG_CACHE_HOME")
        return Path(base) if base else Path.home() / ".cache"


    def mode_path() -> Path:
        return cache_dir() / "dms-codex-usage" / "mode"


    def emit(text: str, tooltip: str, severity: str = "") -> None:
        print(json.dumps({"text": text, "tooltip": tooltip, "class": severity}))


    def normalize_percent(value: float) -> int:
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
                five_hour = {
                    "used_percent": float(raw_pct),
                    "reset_at": window.get("reset_at"),
                }
            elif minutes == 10080:
                weekly = {
                    "used_percent": float(raw_pct),
                    "reset_at": window.get("reset_at"),
                }

        return five_hour, weekly


    def read_mode() -> str:
        try:
            mode = mode_path().read_text(encoding="utf-8").strip()
        except OSError:
            return MODE_USAGE
        return MODE_RESET if mode == MODE_RESET else MODE_USAGE


    def write_mode(mode: str) -> None:
        path = mode_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(mode, encoding="utf-8")


    def toggle_mode() -> str:
        mode = MODE_USAGE if read_mode() == MODE_RESET else MODE_RESET
        write_mode(mode)
        return mode


    def failure_tooltip(message: str) -> str:
        return f"{message}\nClick: toggle usage/reset"


    def fetch_live_limits():
        auth_path = Path.home() / ".codex" / "auth.json"
        try:
            auth = json.loads(auth_path.read_text(encoding="utf-8"))
        except OSError:
            return None, None, "Codex auth not found. Run codex login."
        except json.JSONDecodeError:
            return None, None, "Codex auth is invalid. Re-authenticate with codex login."

        tokens = auth.get("tokens") if isinstance(auth, dict) else None
        if not isinstance(tokens, dict):
            return None, None, "Codex tokens unavailable in auth.json."

        access_token = tokens.get("access_token")
        account_id = tokens.get("account_id")
        if not isinstance(access_token, str) or not access_token:
            return None, None, "Codex access token missing. Re-authenticate with codex login."

        req = request.Request("https://chatgpt.com/backend-api/wham/usage")
        req.add_header("Authorization", f"Bearer {access_token}")
        req.add_header("User-Agent", "codex-cli")
        req.add_header("Accept", "application/json")
        if isinstance(account_id, str) and account_id:
            req.add_header("ChatGPT-Account-Id", account_id)

        try:
            opener = request.build_opener(NoRedirectHandler)
            with opener.open(req, timeout=12) as response:
                payload = json.loads(response.read().decode("utf-8", "replace"))
        except error.HTTPError as exc:
            return None, None, f"Codex API HTTP {exc.code}."
        except (error.URLError, TimeoutError):
            return None, None, "Codex API unreachable."
        except json.JSONDecodeError:
            return None, None, "Codex API returned invalid JSON."

        rate_limit = payload.get("rate_limit") if isinstance(payload, dict) else None
        five_hour, weekly = extract_windows(rate_limit)
        if five_hour is None or weekly is None:
            return None, None, "Codex API missing 5h or weekly rate limits."

        return five_hour, weekly, "live"


    def weekly_reset_text(weekly_limit) -> str:
        reset_at = weekly_limit.get("reset_at") if isinstance(weekly_limit, dict) else None
        if isinstance(reset_at, (int, float)):
            return datetime.fromtimestamp(int(reset_at)).astimezone().strftime("%m/%d %H:%M")
        return "unknown"


    def render(mode: str) -> None:
        five_hour_limit, weekly_limit, status = fetch_live_limits()
        if five_hour_limit is None or weekly_limit is None:
            emit("󰚩 --/--", failure_tooltip(status))
            return

        five_hour_used_pct = normalize_percent(five_hour_limit["used_percent"])
        weekly_used_pct = normalize_percent(weekly_limit["used_percent"])
        five_hour_pct = max(0, 100 - five_hour_used_pct)
        weekly_pct = max(0, 100 - weekly_used_pct)
        weekly_reset = weekly_reset_text(weekly_limit)

        text = f"󰚩 {five_hour_pct}%/{weekly_pct}%"
        if mode == MODE_RESET:
            text = f"󰚩 {weekly_reset}"

        severity = ""
        lowest_remaining = min(five_hour_pct, weekly_pct)
        if lowest_remaining <= 5:
            severity = "critical"
        elif lowest_remaining <= 20:
            severity = "warning"

        emit(
            text,
            (
                f"5h limit: {five_hour_pct}%\n"
                f"Weekly limit: {weekly_pct}%\n"
                f"Weekly reset: {weekly_reset}\n"
                "Click: toggle usage/reset"
            ),
            severity,
        )


    def main() -> int:
        args = sys.argv[1:]
        if args == ["--self-test"]:
            cases = {
                0.0: 0,
                0.5: 0,
                1.0: 1,
                12.5: 12,
                100.0: 100,
            }
            if any(normalize_percent(value) != expected for value, expected in cases.items()):
                return 1
            print("dms-codex-usage self-test: ok")
            return 0
        mode = read_mode()
        if args == ["--toggle"]:
            mode = toggle_mode()
        render(mode)
        return 0


    raise SystemExit(main())
    PY
  '';
}
