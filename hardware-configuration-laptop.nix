# Replace this file on the Asahi laptop with:
#   sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration-laptop.nix
#
# This fallback import keeps evaluation/build working in this repo until the laptop-specific
# hardware profile is generated on the actual machine. It forces the platform to aarch64-linux
# so flake evaluation does not accidentally stay on x86_64 defaults.

{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform = lib.mkForce "aarch64-linux";
}
