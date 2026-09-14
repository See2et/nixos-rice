# Sourced after antidote.zsh; $1 is the immutable plugin manifest.
_hm_antidote_static_dir="$(antidote home)/.home-manager"
mkdir -p -- "$_hm_antidote_static_dir"
zstyle ':antidote:bundle' file "$1"
zstyle ':antidote:static' file "$_hm_antidote_static_dir/${1:t}.zsh"
antidote load "$1" "$_hm_antidote_static_dir/${1:t}.zsh"
unset _hm_antidote_static_dir
