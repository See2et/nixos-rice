# Replace this file on the laptop with:
#   sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration-laptop.nix
#
# This fallback import keeps evaluation/build working in this repo until the laptop-specific
# hardware profile is generated on the actual machine.

{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];
}
