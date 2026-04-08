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
    (_final: prev: {
      direnv = prev.direnv.overrideAttrs (_old: {
        # Work around the current Darwin-only test-fish failure in nixpkgs.
        checkPhase = ''
          runHook preCheck

          make test-go test-bash test-zsh

          runHook postCheck
        '';
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    pnpm
  ];

  programs.zsh.enable = true;
}
