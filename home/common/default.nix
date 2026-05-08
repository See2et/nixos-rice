# Common Home Manager modules shared across all platforms
# Platform-agnostic settings: git, gpg, zsh core, common packages
# CRITICAL: No /mnt/c paths, no WSL notifier, no platform-specific packages
{ ... }:
{
  imports = [
    ./files/opencode.nix
    ./programs/direnv.nix
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
}
