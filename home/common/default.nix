# Common Home Manager modules shared across all platforms
# Platform-agnostic settings: git, gpg, zsh core, common packages, catppuccin theme
# CRITICAL: No /mnt/c paths, no WSL notifier, no platform-specific packages
# NOTE: Dotfile trees (files.nix, xdg.nix) deferred to dotfile migration task

{ inputs, ... }:
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./files/opencode.nix
    ./programs/git.nix
    ./programs/gh.nix
    ./programs/gpg.nix
    ./programs/neovim.nix
    ./programs/zellij.nix
    ./programs/zsh
    ./packages.nix
    ./session.nix
    ./xdg.nix
  ];

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };
}
