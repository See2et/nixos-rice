# WSL Host Configuration
# This module is WSL-specific and should only be imported in the WSL host configuration.
# It imports the nixos-wsl module which provides WSL-specific options and behavior.

{ inputs, ... }:

{
  imports = [
    # Shared baseline (nix.settings, shell, gpg)
    ../../modules/nixos/common
    # WSL-only system settings (nix-ld, allowUnsupportedSystem, usbip)
    ../../modules/nixos/wsl
    inputs.nixos-wsl.nixosModules.default
  ];

  # WSL-specific configuration
  wsl.enable = true;
  system.stateVersion = "25.11";
}
