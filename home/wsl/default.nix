# WSL-specific Home Manager modules
# Settings ONLY for WSL: /mnt/c paths, WSL notifier, WSL-specific env vars
# CRITICAL: Must NOT leak into desktop or darwin HM outputs

{ config, pkgs, inputs, ... }:
{
  imports = [
    ./rebuild.nix
    ./session.nix
    ./files.nix
  ];
}
