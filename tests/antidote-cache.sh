#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/plugin" "$root/home" "$root/tmp"
printf 'typeset -g ANTIDOTE_FIXTURE_LOADED=yes\n' > "$root/plugin/test.plugin.zsh"
printf '%s\n' "$root/plugin" > "$root/plugins.txt"

run_loader() {
  HOME="$root/home" ZDOTDIR="$root/home" TMPDIR="$root/tmp" \
    XDG_CACHE_HOME="$root/cache-$1" \
    ANTIDOTE_SOURCE="$ANTIDOTE_SOURCE" \
    LOADER="$repo_root/home/common/programs/zsh/antidote-load.zsh" \
    MANIFEST="$root/plugins.txt" \
    zsh -dfc '
      unset ANTIDOTE_HOME
      source "$ANTIDOTE_SOURCE"
      source "$LOADER" "$MANIFEST"
      [[ "$ANTIDOTE_FIXTURE_LOADED" == yes ]] || exit 1
      zstyle -s :antidote:static file generated
      [[ "$generated" == "$XDG_CACHE_HOME/antidote/.home-manager/plugins.txt.zsh" ]] || exit 1
      [[ -r "$generated" ]] || exit 1
    '
}

run_loader normal
cp "$root/cache-normal/antidote/.home-manager/plugins.txt.zsh" "$root/normal-before"
run_loader isolated
cmp "$root/normal-before" "$root/cache-normal/antidote/.home-manager/plugins.txt.zsh"
rm -rf "$root/cache-isolated"
run_loader normal
cmp "$root/normal-before" "$root/cache-normal/antidote/.home-manager/plugins.txt.zsh"
printf 'antidote-cache: independent cache roots, unchanged normal bundle, reload after QA cleanup: PASS\n'
