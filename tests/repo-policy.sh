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

match_any() {
  local pattern=$1
  local include=$2
  while IFS= read -r -d '' file; do
    grep -nHE -e "$pattern" "$file" || true
  done < <(
    find "$repo_root" \
      -type f \
      ! -path '*/.git/*' \
      ! -path '*/result/*' \
      ! -name 'AGENTS.md' \
      -name "$include" \
      -print0
  )
}

match_any_many() {
  local pattern=$1
  shift
  local include
  for include in "$@"; do
    match_any "$pattern" "$include"
  done
}

jq_exec() {
  if command -v jq >/dev/null 2>&1; then
    jq "$@"
  elif command -v nix >/dev/null 2>&1; then
    nix shell nixpkgs#jq -c jq "$@"
  else
    return 127
  fi
}

check_absent() {
  local label=$1
  local pattern=$2
  local include=$3
  local matches
  matches=$(match_any "$pattern" "$include")
  if [[ -n "$matches" ]]; then
    fail "$label"
    report "$matches"
  fi
}

check_absent_many() {
  local label=$1
  local pattern=$2
  shift 2
  local matches
  matches=$(match_any_many "$pattern" "$@")
  if [[ -n "$matches" ]]; then
    fail "$label"
    report "$matches"
  fi
}

check_present() {
  local label=$1
  local pattern=$2
  local include=$3
  local matches
  matches=$(match_any "$pattern" "$include")
  if [[ -z "$matches" ]]; then
    fail "$label"
  fi
}

check_present_many() {
  local label=$1
  local pattern=$2
  shift 2
  local matches
  matches=$(match_any_many "$pattern" "$@")
  if [[ -z "$matches" ]]; then
    fail "$label"
  fi
}

check_absent_many "operational laptop output/files/refs must be gone" 'nixosConfigurations\.laptop|#laptop|hosts[/-]laptop|home[/-]laptop|modules/.*/laptop|hardware-configuration-laptop|hardware-laptop|WSL/Laptop' '*.nix' '*.md' '*.jsonc'

check_absent "home.activation must not mutate SteamVR/VRChat/Oyasumi/ALVR state" 'home\.activation\.[A-Za-z0-9_]*(steamVr|vrchat|oyasumi|alvr)[A-Za-z0-9_]*' '*.nix'

check_absent "localconfig.vdf or ALVR session.json must not be mutated by Home Manager" 'localconfig\.vdf|session\.json' '*.nix'

check_absent_many "Home Manager must not generate OpenXR active runtime" 'active_runtime(\.x86_64)?\.json' '*.nix' '*.md' '*.jsonc'

check_absent "nonstandard OPENXR_RUNTIME_JSON must not appear in source ownership" 'OPENXR_RUNTIME_JSON' '*.nix'

check_absent "home .local/bin/steam must not shadow programs.steam" '\.local/bin/steam' '*.nix'

check_absent "wlx-overlay-s package/wrapper/config path must be removed" 'wlx-overlay-s' '*.nix'

wayvr_mutable_matches=$(match_any '(^|["/])(zz-saved[^"/]*|pw_tokens|wayvr\.vrmanifest|actions\.json|actions_binding_[^"/]*)(["/]|$)' '*.nix')
wayvr_mutable_matches=$(printf '%s\n' "$wayvr_mutable_matches" | grep -v 'wayvr/src/res/actions_binding_oculus\.json' || true)
if [[ -n $wayvr_mutable_matches ]]; then
  fail "WayVR must not own mutable runtime files; immutable package seed bindings are the only exception"
  report "$wayvr_mutable_matches"
fi

check_present "WayVR must be sourced from base nixpkgs" 'inputs\.nixpkgs\.legacyPackages\.\$\{pkgs\.stdenv\.hostPlatform\.system\}\.wayvr' 'wayvr.nix'

check_absent "WayVR must not be sourced from non-base nixpkgs inputs" 'inputs\.(nixpkgs-unstable|nixpkgs-compat|nixpkgs-steam|nixpkgs-xr)\.legacyPackages\..*\.wayvr' 'wayvr.nix'

check_absent "WayVR 26.2.1 launchers must not use --wait" '--wait' 'wayvr.nix'

check_present "WayVR OpenVR launcher must show the dashboard on startup" 'wayvr\s+--openvr\s+--show' 'wayvr.nix'

check_present "WayVR OpenVR launcher must declare libglvnd" 'pkgs\.libglvnd' 'wayvr.nix'

check_present "WayVR OpenVR launcher must declare libuuid" 'pkgs\.libuuid' 'wayvr.nix'

check_present "WayVR OpenVR launcher must declare vulkan-loader" 'pkgs\.vulkan-loader' 'wayvr.nix'

check_present "WayVR OpenVR launcher must prepend an explicit library path without an empty search entry" 'LD_LIBRARY_PATH="\$\{wayvrOpenvrRuntimeLibraryPath\}.*LD_LIBRARY_PATH:\+:\$LD_LIBRARY_PATH' 'wayvr.nix'

check_absent "WayVR OpenVR launcher must not inject broad Steam Runtime wrappers or preload hooks" 'steam-run|steam-runtime|scout|sniper|LD_PRELOAD' 'wayvr.nix'

check_present "WayVR package must embed the declared Oculus Touch binding" 'actions_binding_oculus\.json' 'wayvr.nix'

check_present "WayVR on Niri must use the verified PipeWire GPU capture path" '^capture_method:[[:space:]]*pipewire$' 'config.yaml'

check_absent "WayVR must not use CPU fallback capture that fails Niri format negotiation" '^capture_method:[[:space:]]*(pw-fallback|pw_fallback)$' 'config.yaml'

check_present "WayVR Space Drag must allow three-axis movement" '^space_drag_unlocked:[[:space:]]*true$' 'config.yaml'

check_present "WayVR Space Turn must remain yaw-only" '^space_rotate_unlocked:[[:space:]]*false$' 'config.yaml'

wayvr_oculus_binding="$repo_root/home/desktop/vr/wayvr/oculus-touch-binding.json"
if [[ ! -f $wayvr_oculus_binding ]]; then
  fail "WayVR Oculus Touch binding profile must exist"
elif ! jq_exec -e '
  .bindings["/actions/default"].sources as $sources
  | any($sources[];
      .path == "/user/hand/left/input/x"
      and .inputs.double.output == "/actions/default/in/showhide"
      and (.inputs | has("click") | not))
    and any($sources[];
      .path == "/user/hand/left/input/y"
      and .inputs.click.output == "/actions/default/in/spacedrag"
      and (.inputs | has("double") | not))
    and any($sources[];
      .path == "/user/hand/right/input/b"
      and .inputs.click.output == "/actions/default/in/spacerotate")
' "$wayvr_oculus_binding" >/dev/null; then
  fail "WayVR Oculus Touch binding must split Y hold SpaceDrag, double-X ShowHide, and B hold SpaceRotate across distinct inputs"
fi

check_present "home/desktop/vr/alvr.nix must override pkgs.ffmpeg for patchedFfmpeg" 'patchedFfmpeg\s*=\s*pkgs\.ffmpeg\.(override|overrideAttrs)\b' 'alvr.nix'

check_present "home/desktop/vr/alvr.nix must pass patchedFfmpeg into pkgs.alvr.override" 'pkgs\.alvr\.override' 'alvr.nix'

alvr_binding_name_matches=$(match_any '^[[:space:]]*alvr[[:space:]]*=' 'alvr.nix')
alvr_binding_override_matches=$(match_any 'pkgs\.alvr\.override' 'alvr.nix')
alvr_binding_final_override_matches=$(match_any 'overrideAttrs' 'alvr.nix')
if [[ -z "$alvr_binding_name_matches" || -z "$alvr_binding_override_matches" || -z "$alvr_binding_final_override_matches" ]]; then
  fail "home/desktop/vr/alvr.nix must bind the overridden ALVR package for wrappers"
  report "$alvr_binding_name_matches"
  report "$alvr_binding_override_matches"
  report "$alvr_binding_final_override_matches"
fi

alvr_early_hmd_source_matches=$(match_any 'let\s+early_hmd_initialization\s*=\s*!\s*dashboard_process_paths\.is_empty\(\)\s*;' 'alvr.nix')
alvr_early_hmd_override_matches=$(match_any 'let\s+early_hmd_initialization\s*=\s*true\s*;' 'alvr.nix')
if [[ -z "$alvr_early_hmd_source_matches" || -z "$alvr_early_hmd_override_matches" ]]; then
  fail "home/desktop/vr/alvr.nix must bind the ALVR 20.14.1 shutdown-regression workaround by keeping the original early_hmd_initialization source target and forcing early_hmd_initialization = true;"
  report "$alvr_early_hmd_source_matches"
  report "$alvr_early_hmd_override_matches"
fi

check_present "home/desktop/vr/alvr.nix wrappers must use the overridden ALVR package" 'runtimeInputs\s*=\s*\[\s*alvr\s*\]' 'alvr.nix'

check_present "home/desktop/vr/alvr.nix wrappers must exec the overridden ALVR package" 'exec\s+"\$\{alvr\}/bin/alvr_(dashboard|launcher)"' 'alvr.nix'

check_absent "home/desktop/vr/alvr.nix wrappers must not exec pkgs.alvr directly" '\$\{pkgs\.alvr\}/bin/alvr_(dashboard|launcher)' 'alvr.nix'

check_absent "home/desktop/vr/alvr.nix wrappers must not depend on pkgs.alvr directly" 'runtimeInputs\s*=\s*\[\s*pkgs\.alvr\s*\]' 'alvr.nix'

check_present "ALVR quality profile command must be packaged" 'name\s*=\s*"alvr-quality-profile"' 'tools.nix'

check_present "ALVR quality profile command must load its dedicated tool" 'builtins\.readFile\s+\./tools/alvr-quality-profile' 'tools.nix'

check_present "ALVR quality profile command must use the live dashboard API" '/api/dashboard-request' 'alvr-quality-profile'

check_present "ALVR quality profile must pin HEVC" '^PROFILE_CODEC=Hevc$' 'alvr-quality-profile'

check_present "ALVR quality profile must pin 35 Mbps" '^PROFILE_BITRATE_MBPS=35$' 'alvr-quality-profile'

check_present "ALVR quality profile must pin foveation center X" '^PROFILE_CENTER_X=0\.6$' 'alvr-quality-profile'

check_present "ALVR quality profile must pin foveation center Y" '^PROFILE_CENTER_Y=0\.55$' 'alvr-quality-profile'

check_present "ALVR quality profile must pin foveation edge ratio X" '^PROFILE_EDGE_RATIO_X=2\.0$' 'alvr-quality-profile'

check_present "ALVR quality profile must pin foveation edge ratio Y" '^PROFILE_EDGE_RATIO_Y=2\.5$' 'alvr-quality-profile'

check_absent "ALVR quality profile command must not write session.json directly" '(>|cp|mv|install|rm|truncate|tee)[^[:cntrl:]]*session\.json' 'alvr-quality-profile'

check_absent "ALVR quality profile command must not run from activation" 'home\.activation\.[A-Za-z0-9_]*alvr[A-Za-z0-9_]*|alvr-quality-profile[[:space:]]+apply' '*.nix'

check_present_many "ALVR patch source must contain the Vulkan-to-CUDA packed format channel count fix" '\.NumChannels\s*=\s*desc->comp\[i\]\.step\s*/\s*elem_size' '*.nix' '*.patch'

check_present_many "ALVR patch source must contain the packed-format depth-aware channel count fix" '1\s*\+\s*\(desc->comp\[0\]\.depth\s*>\s*8\)' '*.nix' '*.patch'

steam_ffmpeg_headless_matches=$(match_any 'patchedFfmpegHeadless\s*=\s*prev\.ffmpeg-headless\.(override|overrideAttrs)\b' 'steam.nix')
steam_ffmpeg_patch_matches=$(match_any 'ffmpeg-8\.0-vulkan-cuda-packed-format\.patch' 'steam.nix')
steam_desktop_overlay_matches=$(match_any 'nixpkgs\.overlays\s*=\s*\[\s*steamFfmpegOverlay\s*\]' 'steam.nix')
steam_vaapi_matches=$(match_any 'nvidia-vaapi-driver\s*=\s*prev\.nvidia-vaapi-driver\.override' 'steam.nix')
if [[ -z "$steam_ffmpeg_headless_matches" || -z "$steam_ffmpeg_patch_matches" || -z "$steam_desktop_overlay_matches" || -z "$steam_vaapi_matches" ]]; then
  fail "modules/nixos/desktop/steam.nix must feed patched ffmpeg-headless into Steam's NVIDIA VA-API closure"
fi

check_absent "home/wsl/rebuild.nix must not direct-switch re helper" 'programs\.zsh\.zsh-abbr\.abbreviations\.re\s*=\s*"sudo nixos-rebuild (switch|test) --flake /etc/nixos#wsl"' 'rebuild.nix'
check_present "home/wsl/rebuild.nix must start re helper with dry-activate" 'programs\.zsh\.zsh-abbr\.abbreviations\.re\s*=\s*"sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl"' 'rebuild.nix'

if [[ $failures -gt 0 ]]; then
  report "Policy checks failed: $failures"
  exit 1
fi

report "Policy checks passed"
