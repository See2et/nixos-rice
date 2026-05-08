# Darwin system baseline
# Platform-neutral HM config stays in home/common.

{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../overlays/darwin/direnv.nix)
  ];

  environment.systemPackages = with pkgs; [
    pnpm
  ];

  programs.zsh.enable = true;
}
