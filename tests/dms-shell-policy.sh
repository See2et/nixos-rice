#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

failures=0

report() {
	printf '%s\n' "$1"
}

fail() {
	report "FAIL: $1"
	failures=$((failures + 1))
}

check_present() {
	local label=$1
	local pattern=$2
	local file=$3
	local path="$repo_root/$file"

	if [[ ! -f "$path" ]]; then
		fail "$label (missing file: $file)"
		return
	fi

	if ! grep -nE "$pattern" "$path" >/dev/null; then
		fail "$label"
	fi
}

check_absent() {
	local label=$1
	local pattern=$2
	local file=$3
	local path="$repo_root/$file"
	local matches

	if [[ ! -f "$path" ]]; then
		return
	fi

	matches=$(grep -nE "$pattern" "$path" || true)
	if [[ -n "$matches" ]]; then
		fail "$label"
		report "$matches"
	fi
}

check_present_pcre() {
	local label=$1
	local pattern=$2
	local file=$3
	local path="$repo_root/$file"

	if [[ ! -f "$path" ]]; then
		fail "$label (missing file: $file)"
		return
	fi

	if ! grep -Pzo "$pattern" "$path" >/dev/null; then
		fail "$label"
	fi
}

check_absent_pcre() {
	local label=$1
	local pattern=$2
	local file=$3
	local path="$repo_root/$file"
	local matches

	if [[ ! -f "$path" ]]; then
		return
	fi

	matches=$(grep -Pzon "$pattern" "$path" | tr '\0' '\n' || true)
	if [[ -n "$matches" ]]; then
		fail "$label"
		report "$matches"
	fi
}

check_file_exists() {
	local label=$1
	local file=$2
	if [[ ! -f "$repo_root/$file" ]]; then
		fail "$label"
	fi
}

check_glob_exists() {
	local label=$1
	local glob_pattern=$2
	local matches=()

	shopt -s nullglob
	matches=("$repo_root"/$glob_pattern)
	shopt -u nullglob

	if ((${#matches[@]} == 0)); then
		fail "$label"
	fi
}

check_unlock_patch_exists() {
	local label=$1
	local flavor=$2
	local found=0
	local path
	local base

	shopt -s nullglob
	for path in "$repo_root"/patches/*unlock*.patch; do
		base=${path##*/}
		case "$flavor" in
		core)
			if [[ ! "$base" =~ [Qq][Mm][Ll] ]]; then
				found=1
				break
			fi
			;;
		qml)
			if [[ "$base" =~ [Qq][Mm][Ll] ]]; then
				found=1
				break
			fi
			;;
		esac
	done
	shopt -u nullglob

	if ((found == 0)); then
		fail "$label"
	fi
}

check_present "flake input must pin DankMaterialShell v1.5.2" '^[[:space:]]*dms[[:space:]]*=.*v1\.5\.2|url[[:space:]]*=[[:space:]]*"github:AvengeMedia/DankMaterialShell/v1\.5\.2' 'flake.nix'
check_present_pcre "flake must define dmsPackage as a patched package" '(?s)dmsPackage[[:space:]]*=.*?(override|overrideAttrs)' 'flake.nix'
check_present "flake dmsPackage must reference a core unlock-removal patch" 'patches/[^";]*unlock[^";]*(core|ipc|loginctl)|patches/[^";]*(core|ipc|loginctl)[^";]*unlock' 'flake.nix'
check_present "flake dmsPackage must reference a QML unlock-removal patch" 'patches/[^";]*qml[^";]*unlock|patches/[^";]*unlock[^";]*qml' 'flake.nix'
check_present "flake dmsPackage must reference the fixed PAM authentication patch" 'patches/[^";]*pam[^";]*(auth|boundary)|patches/[^";]*(auth|boundary)[^";]*pam' 'flake.nix'
check_present "flake dmsPackage must reference the pinned suspend-lock core patch" 'dms-core-pin-suspend-lock\.patch' 'flake.nix'
check_present "flake dmsPackage must reference the pinned QML lock-control patch" 'dms-qml-pin-lock-control\.patch' 'flake.nix'
check_present "DMS security gate must reject mutable loginctl integration" 'SettingsData\.loginctlLockIntegration' 'flake.nix'
check_present "DMS security gate must require protected settings IPC" 'SETTINGS_PROTECTED_KEY' 'flake.nix'
check_unlock_patch_exists "patches/ must contain a core unlock-removal patch" 'core'
check_unlock_patch_exists "patches/ must contain a QML unlock-removal patch" 'qml'
check_file_exists "patches/ must contain a fixed PAM authentication patch" 'patches/dms-qml-pin-pam-auth-boundary.patch'
check_file_exists "patches/ must contain a pinned suspend-lock core patch" 'patches/dms-core-pin-suspend-lock.patch'
check_file_exists "patches/ must contain a pinned QML lock-control patch" 'patches/dms-qml-pin-lock-control.patch'
check_absent "desktop host must not import the DMS NixOS module when HM owns the package" 'inputs\.dms\.nixosModules\.dank-material-shell' 'hosts/desktop/default.nix'
check_present "desktop host must pass dmsPackage into HM extraSpecialArgs" 'inherit dmsPackage|dmsPackage[[:space:]]*=[[:space:]]*dmsPackage' 'hosts/desktop/default.nix'
check_present "desktop profile must import a dedicated DMS module" '\./dank-material-shell\.nix' 'home/desktop/default.nix'
check_file_exists "desktop DMS profile must exist" 'home/desktop/dank-material-shell.nix'
check_file_exists "desktop DMS theme module must exist" 'home/desktop/dms/theme.nix'
check_file_exists "desktop DMS settings module must exist" 'home/desktop/dms/settings.nix'
check_file_exists "desktop DMS bindings module must exist" 'home/desktop/dms/bindings.nix'
check_file_exists "desktop DMS Codex usage package must exist" 'home/desktop/dms/codex-usage.nix'
check_file_exists "desktop DMS Codex widget manifest must exist" 'home/desktop/dms/plugins/codex-usage/plugin.json'
check_file_exists "desktop DMS Codex widget must exist" 'home/desktop/dms/plugins/codex-usage/CodexUsageWidget.qml'
check_file_exists "desktop DMS emoji launcher manifest must exist" 'home/desktop/dms/plugins/emoji-launcher/plugin.json'
check_file_exists "desktop DMS emoji launcher must exist" 'home/desktop/dms/plugins/emoji-launcher/EmojiLauncher.qml'
check_file_exists "desktop DMS emoji launcher data must exist" 'home/desktop/dms/plugins/emoji-launcher/EmojiData.js'
check_present "desktop DMS profile must import the HM shell module" 'inputs\.dms\.homeModules\.dank-material-shell' 'home/desktop/dank-material-shell.nix'
check_absent "desktop DMS profile must not import an empty HM niri include layer" 'inputs\.dms\.homeModules\.niri' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must enable the module-managed systemd integration" 'systemd\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_absent "desktop DMS profile must not configure unused DMS niri include options" '^[[:space:]]*niri\.(enableSpawn|enableKeybinds|includes)' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must wire the split theme JSON module" 'xdg\.configFile\."DankMaterialShell/themes/see2et-graphite-cyan\.json"\.text[[:space:]]*=[[:space:]]*dmsTheme[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must wire the split settings module" 'settings[[:space:]]*=[[:space:]]*dmsSettings[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must wire the split niri binds module" 'programs\.niri\.settings\.binds[[:space:]]*=[[:space:]]*dmsBindings[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must take package ownership from HM args" 'package[[:space:]]*=[[:space:]]*dmsPackage[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must declaratively enable plugin state" 'managePluginSettings[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must enable the Codex usage plugin" 'codexUsage[[:space:]]*=[[:space:]]*\{' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must enable the emoji launcher plugin" 'emojiLauncher[[:space:]]*=[[:space:]]*\{' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS settings module must set configVersion 12" 'configVersion[[:space:]]*=[[:space:]]*12[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS settings module must mark PAM as externally managed" 'lockPamExternallyManaged[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS settings module must point lockPamPath at the root-owned dankshell PAM file" 'lockPamPath[[:space:]]*=[[:space:]]*"/etc/pam\.d/dankshell"[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS settings module must hide lock-screen power actions" 'lockScreenShowPowerActions[[:space:]]*=[[:space:]]*false[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS settings module must wire the custom theme path" 'customThemeFile[[:space:]]*=[[:space:]]*customThemePath[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS settings module must wire the wallpaper path into the lock screen" 'lockScreenWallpaperPath[[:space:]]*=[[:space:]]*wallpaper[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS bar must retain the Codex usage indicator" '"codexUsage"' 'home/desktop/dms/settings.nix'
check_present "desktop DMS must begin the fade early enough to lock at five minutes" 'acLockTimeout[[:space:]]*=[[:space:]]*240[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_present "desktop DMS battery idle policy must also lock at five minutes" 'batteryLockTimeout[[:space:]]*=[[:space:]]*240[[:space:]]*;' 'home/desktop/dms/settings.nix'
check_absent "Codex percentage normalization must not reinterpret small percentages as ratios" 'value[[:space:]]*\*=[[:space:]]*100\.0' 'home/desktop/dms/codex-usage.nix'
check_present "Codex helper must reject HTTP redirects before sending credentials elsewhere" 'HTTPRedirectHandler|redirect_request' 'home/desktop/dms/codex-usage.nix'
check_absent "Codex widget must not read widgetThickness from its Loader parent" 'parent\.widgetThickness' 'home/desktop/dms/plugins/codex-usage/CodexUsageWidget.qml'
check_present "Codex widget must size against the PluginComponent contract" 'root\.widgetThickness' 'home/desktop/dms/plugins/codex-usage/CodexUsageWidget.qml'
check_present "Codex widget must namespace Proc calls by screen" 'parentScreen.*name|processKey' 'home/desktop/dms/plugins/codex-usage/CodexUsageWidget.qml'
check_absent "desktop DMS profile must not set deprecated clipboard disableHistory" 'disableHistory[[:space:]]*=' 'home/desktop/dank-material-shell.nix'
check_absent "desktop DMS profile must not set deprecated clipboard disablePersist" 'disablePersist[[:space:]]*=' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must keep all-screen screenshot wrapper" 'dmsScreenshotAll[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"dms-screenshot-all"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must keep region screenshot wrapper" 'dmsScreenshotRegion[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"dms-screenshot-region"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must define focused-window screenshot wrapper" 'dmsScreenshotWindow[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"dms-screenshot-window"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must define focused-output screenshot wrapper" 'dmsScreenshotFull[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"dms-screenshot-full"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must define random wallpaper wrapper" 'dmsWallpaperRandom[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"dms-wallpaper-random"' 'home/desktop/dank-material-shell.nix'
check_present_pcre "desktop DMS bindings module must define the spotlight toggle bind" '(?s)"Ctrl\+Space"\.action\.spawn[[:space:]]*=[[:space:]]*\[[[:space:]]*dms[[:space:]]+"ipc"[[:space:]]+"call"[[:space:]]+"spotlight"[[:space:]]+"toggle"[[:space:]]*\]' 'home/desktop/dms/bindings.nix'
check_present_pcre "desktop DMS bindings module must define the powermenu toggle bind" '(?s)"Mod\+Escape"\.action\.spawn[[:space:]]*=[[:space:]]*\[[[:space:]]*dms[[:space:]]+"ipc"[[:space:]]+"call"[[:space:]]+"powermenu"[[:space:]]+"toggle"[[:space:]]*\]' 'home/desktop/dms/bindings.nix'
check_present_pcre "desktop DMS bindings module must open the emoji launcher directly" '(?s)"Mod\+E"\.action\.spawn[[:space:]]*=[[:space:]]*\[[^]]*"spotlight"[^]]*"openQuery"[^]]*":"' 'home/desktop/dms/bindings.nix'
check_present "desktop DMS bindings module must bind focused-window screenshots directly" '"Mod\+Ctrl\+S"\.action\.spawn[[:space:]]*=[[:space:]]*\[[[:space:]]*"dms-screenshot-window"' 'home/desktop/dms/bindings.nix'
check_present "desktop DMS bindings module must bind focused-output screenshots directly" '"Mod\+Alt\+S"\.action\.spawn[[:space:]]*=[[:space:]]*\[[[:space:]]*"dms-screenshot-full"' 'home/desktop/dms/bindings.nix'
check_absent_pcre "desktop DMS bindings module wallpaper binding must stop using file browse wallpaper" '(?s)"Mod\+Shift\+W"\.action\.spawn[[:space:]]*=[[:space:]]*\[[^]]*"file"[^]]*"browse"[^]]*"wallpaper"' 'home/desktop/dms/bindings.nix'
check_present_pcre "desktop DMS bindings module wallpaper binding must open the settings wallpaper tab" '(?s)"Mod\+Shift\+W"\.action\.spawn[[:space:]]*=[[:space:]]*\[[^]]*"settings"[^]]*"wallpaper"' 'home/desktop/dms/bindings.nix'
check_present_pcre "desktop DMS bindings module must preserve next wallpaper access" '(?s)action\.spawn[[:space:]]*=[[:space:]]*\[[^]]*"wallpaper"[^]]*"next"' 'home/desktop/dms/bindings.nix'
check_present_pcre "desktop DMS bindings module must preserve previous wallpaper access" '(?s)action\.spawn[[:space:]]*=[[:space:]]*\[[^]]*"wallpaper"[^]]*"prev"' 'home/desktop/dms/bindings.nix'
check_present "desktop DMS bindings module must preserve random wallpaper access" '"Mod\+Ctrl\+Alt\+W"\.action\.spawn[[:space:]]*=[[:space:]]*\[[[:space:]]*"dms-wallpaper-random"' 'home/desktop/dms/bindings.nix'
check_present "desktop DMS profile must coerce the wallpaper directory through the store" 'wallpaperDirectory[[:space:]]*=[[:space:]]*\.\./\.\./assets/wallpapers' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session must preserve automatic wallpaper cycling" 'wallpaperCyclingEnabled[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session must preserve the twenty-minute wallpaper interval" 'wallpaperCyclingInterval[[:space:]]*=[[:space:]]*1200[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session must pin weather to Kanagawa" 'weatherLocation[[:space:]]*=[[:space:]]*"Kanagawa, Japan"[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session must pin Kanagawa coordinates" 'weatherCoordinates[[:space:]]*=[[:space:]]*"35\.4478,139\.6425"[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must declaratively own the user icon" 'home\.file\."\.face"\.source[[:space:]]*=[[:space:]]*profileImage[[:space:]]*;' 'home/desktop/dank-material-shell.nix'
check_absent "desktop DMS profile must stop managing immutable DMS session attrsets" '^[[:space:]]*session[[:space:]]*=[[:space:]]*\{' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS profile must bootstrap mutable DMS session runtime state" 'session\.json|bootstrap' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session bootstrap must honor Home Manager dry runs" '\$DRY_RUN_CMD' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session bootstrap must create user-writable private state" 'install[[:space:]]+-m[[:space:]]+0600' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session update must atomically replace existing state" 'mv[[:space:]]+-f[[:space:]]+"\$session_tmp"[[:space:]]+"\$session_path"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session update must secure temporary state before replacement" 'chmod[[:space:]]+0600[[:space:]]+"\$session_tmp"' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS session update must clean temporary state on failure" 'trap.*session_tmp' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS service PATH must expose the module-selected dgop package" 'config\.programs\.dank-material-shell\.dgop\.package' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS service PATH must expose the configured niri package" 'config\.programs\.niri\.package' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS service PATH must retain the root-owned system profile" '/run/current-system/sw/bin' 'home/desktop/dank-material-shell.nix'
check_present "desktop DMS service PATH must resolve user-profile desktop entry commands" 'config\.home\.profileDirectory.*/bin' 'home/desktop/dank-material-shell.nix'
check_absent "desktop Slack entry must not launch in silent mode" 'Exec=.*[[:space:]]-s([[:space:]]|$)' 'home/desktop/packages.nix'
check_present "desktop Slack entry must bypass the crashing GPU process" 'Exec=\$\{lib\.getExe pkgs\.slack\}[[:space:]]+--disable-gpu[[:space:]]+%U' 'home/desktop/packages.nix'
check_file_exists "Pear package must carry the window lifecycle patch" 'patches/pear-desktop-window-lifecycle.patch'
check_present "desktop packages must patch Pear at the package lifecycle layer" 'pearDesktopPatched[[:space:]]*=[[:space:]]*pkgs\.pear-desktop\.overrideAttrs' 'home/desktop/packages.nix'
check_present_pcre "patched Pear package must apply the lifecycle patch during source build" '(?s)patches[[:space:]]*=[[:space:]]*\(old\.patches or \[[[:space:]]*\]\).*?pear-desktop-window-lifecycle\.patch' 'home/desktop/packages.nix'
check_absent "patched Pear package must not repack generated ASAR output" 'asar[[:space:]]+(extract|pack)' 'home/desktop/packages.nix'
check_present "desktop package list must use the patched Pear package" 'pearDesktopPatched' 'home/desktop/packages.nix'
check_present "Pear lifecycle patch must create visible windows eagerly when configured visible" "show:[[:space:]]+config\.get\('options\.appVisible'\)" 'patches/pear-desktop-window-lifecycle.patch'

check_present "desktop system DMS module must define a root-owned dankshell PAM service" 'security\.pam\.services\.dankshell' 'modules/nixos/desktop/dank-material-shell.nix'
check_present "desktop system DMS PAM service must reject null passwords" 'allowNullPassword[[:space:]]*=[[:space:]]*false[[:space:]]*;' 'modules/nixos/desktop/dank-material-shell.nix'
check_present "desktop system DMS module must enable accounts-daemon" 'services\.accounts-daemon\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'modules/nixos/desktop/dank-material-shell.nix'
check_present "desktop system DMS module must enable geoclue" 'services\.geoclue2\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'modules/nixos/desktop/dank-material-shell.nix'
check_present "desktop system DMS module must enable power profiles" 'services\.power-profiles-daemon\.enable[[:space:]]*=[[:space:]]*true[[:space:]]*;' 'modules/nixos/desktop/dank-material-shell.nix'
check_absent "desktop system DMS module must not own programs.dank-material-shell" 'programs\.dank-material-shell' 'modules/nixos/desktop/dank-material-shell.nix'

check_present "desktop profile must keep packages import for custom alacritty-cwd" '\./packages\.nix' 'home/desktop/default.nix'
check_present "desktop profile must keep VR import ownership" '\./vr' 'home/desktop/default.nix'
check_present "desktop profile must keep Zen import ownership" '\./zen-browser\.nix' 'home/desktop/default.nix'
check_present "desktop profile must keep XDG import ownership" '\./xdg\.nix' 'home/desktop/default.nix'
check_present "custom alacritty-cwd wrapper must remain defined" 'alacrittyCwd[[:space:]]*=[[:space:]]*pkgs\.writeShellScriptBin[[:space:]]*"alacritty-cwd"' 'home/desktop/packages.nix'

check_absent "desktop profile must stop importing HM bluetooth ownership" '\./bluetooth\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing HM wallpaper ownership" '\./wallpaper\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing HM idle ownership" '\./idle\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing HM Waybar ownership" '\./waybar\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing HM Rofi ownership" '\./rofi\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing HM surfaces ownership" '\./surfaces\.nix' 'home/desktop/default.nix'
check_absent "desktop profile must stop importing old shell startup ordering" '\./session-startup\.nix' 'home/desktop/default.nix'

check_absent "desktop packages must stop owning Rofi and Cliphist shell packages" '(^|[^[:alnum:]_-])(rofi|rofimoji|cliphist)([^[:alnum:]_-]|$)' 'home/desktop/packages.nix'
check_absent "desktop packages must stop owning Waybar, wlogout, and swaylock shell packages" '(^|[^[:alnum:]_-])(waybar|wlogout|swaylock-effects)([^[:alnum:]_-]|$)' 'home/desktop/packages.nix'
check_absent "desktop packages must stop defining old shell launchers and pickers" 'rofiLauncher|cliphistPicker|emojiPicker|desktopPowerMenu' 'home/desktop/packages.nix'

check_absent "desktop niri bindings must stop launching old shell entrypoints" 'rofi-launcher|cliphist-picker|emoji-picker|desktop-power-menu|desktop-wallpaper-menu|desktop-lock' 'home/desktop/niri.nix'
check_absent "desktop surfaces must stop owning SwayNC" 'services\.swaync' 'home/desktop/surfaces.nix'
check_absent "desktop surfaces must stop owning swaylock" 'programs\.swaylock' 'home/desktop/surfaces.nix'
check_absent "desktop surfaces must stop owning wlogout" 'programs\.wlogout' 'home/desktop/surfaces.nix'
check_absent "desktop idle module must stop owning swayidle" 'services\.swayidle' 'home/desktop/idle.nix'
check_absent "desktop wallpaper module must stop owning awww" 'pkgs\.awww|/bin/awww|/bin/awww-daemon' 'home/desktop/wallpaper.nix'
check_absent "desktop Waybar module must stop owning Waybar" 'programs\.waybar|swaync-client' 'home/desktop/waybar.nix'
check_absent "desktop Rofi module must stop owning Rofi" 'programs\.rofi|rofi' 'home/desktop/rofi.nix'
check_absent "desktop bluetooth module must stop owning the Blueman applet" 'services\.blueman-applet\.enable[[:space:]]*=[[:space:]]*true' 'home/desktop/bluetooth.nix'
check_absent "desktop system bluetooth module must not enable Blueman" 'services\.blueman\.enable[[:space:]]*=[[:space:]]*true' 'modules/nixos/desktop/bluetooth.nix'
check_absent "desktop system profile must stop shipping old shell packages" '^[[:space:]]*(fuzzel|waybar|swaybg)[[:space:]]*$' 'modules/nixos/desktop/system.nix'

check_present "desktop niri clipboard block must cover every dms:clipboard namespace" 'namespace[[:space:]]*=[[:space:]]*"\^dms:clipboard\.\*.*"[[:space:]]*;' 'home/desktop/niri.nix'

if ((failures > 0)); then
	report "dms-shell-policy: ${failures} failure(s)"
	exit 1
fi

report "dms-shell-policy: ok"
