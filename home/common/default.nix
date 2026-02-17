# Common Home Manager modules shared across all platforms
# Platform-agnostic settings: git, gpg, zsh core, common packages, dotfiles
# CRITICAL: No /mnt/c paths, no WSL notifier, no platform-specific packages

{ config, pkgs, inputs, ... }:
{
  imports = [
    ./programs/git.nix
    ./programs/gh.nix
    ./programs/gpg.nix
    ./programs/zsh
    ./packages.nix
    ./session.nix
    ./xdg.nix
    ./files.nix
  ];
}
