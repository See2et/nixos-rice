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

check_absent_many "operational laptop output/files/refs must be gone" 'nixosConfigurations\.laptop|#laptop|hosts[/-]laptop|home[/-]laptop|modules/.*/laptop|hardware-configuration-laptop|hardware-laptop|WSL/Laptop' '*.nix' '*.md' '*.jsonc'

check_absent "home.activation must not mutate SteamVR/VRChat/Oyasumi/ALVR state" 'home\.activation\.[A-Za-z0-9_]*(steamVr|vrchat|oyasumi|alvr)[A-Za-z0-9_]*' '*.nix'

check_absent "localconfig.vdf or ALVR session.json must not be mutated by Home Manager" 'localconfig\.vdf|session\.json' '*.nix'

check_absent_many "Home Manager must not generate OpenXR active runtime" 'active_runtime(\.x86_64)?\.json' '*.nix' '*.md' '*.jsonc'

check_absent "nonstandard OPENXR_RUNTIME_JSON must not appear in source ownership" 'OPENXR_RUNTIME_JSON' '*.nix'

check_absent "home .local/bin/steam must not shadow programs.steam" '\.local/bin/steam' '*.nix'

check_absent "wlx-overlay-s package/wrapper/config path must be removed" 'wlx-overlay-s' '*.nix'

check_absent "WayVR must not own mutable runtime files" '(^|["/])(zz-saved[^"/]*|pw_tokens|wayvr\.vrmanifest|actions\.json|actions_binding_[^"/]*)(["/]|$)' '*.nix'

check_present "WayVR must be sourced from base nixpkgs" 'inputs\.nixpkgs\.legacyPackages\.\$\{pkgs\.stdenv\.hostPlatform\.system\}\.wayvr' 'wayvr.nix'

check_absent "WayVR must not be sourced from non-base nixpkgs inputs" 'inputs\.(nixpkgs-unstable|nixpkgs-compat|nixpkgs-steam|nixpkgs-xr)\.legacyPackages\..*\.wayvr' 'wayvr.nix'

check_absent "WayVR 26.2.1 launchers must not use --wait" '--wait' 'wayvr.nix'

check_absent "home/wsl/rebuild.nix must not direct-switch re helper" 'programs\.zsh\.zsh-abbr\.abbreviations\.re\s*=\s*"sudo nixos-rebuild (switch|test) --flake /etc/nixos#wsl"' 'rebuild.nix'
check_present "home/wsl/rebuild.nix must start re helper with dry-activate" 'programs\.zsh\.zsh-abbr\.abbreviations\.re\s*=\s*"sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl"' 'rebuild.nix'

if [[ $failures -gt 0 ]]; then
  report "Policy checks failed: $failures"
  exit 1
fi

report "Policy checks passed"
