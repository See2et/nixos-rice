# WSL Host Configuration
# This module is WSL-specific and should only be imported in the WSL host configuration.
# It imports the nixos-wsl module which provides WSL-specific options and behavior.

{ inputs, pkgs, ... }:

{
  imports = [
    # Shared baseline (nix.settings, shell, gpg)
    ../../modules/nixos/common
    # WSL-only system settings (nix-ld, allowUnsupportedSystem, usbip)
    ../../modules/nixos/wsl
    inputs.nixos-wsl.nixosModules.default
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
  ];

  # WSL-specific configuration
  wsl.enable = true;
  users.users.nixos.shell = pkgs.zsh;
  system.stateVersion = "25.11";

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.overwriteBackup = true;
  home-manager.users.nixos = {
    imports = [
      ../../home/common
      ../../home/linux
      ../../home/wsl
    ];
    home.username = "nixos";
    home.homeDirectory = "/home/nixos";
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
  };
  home-manager.extraSpecialArgs = {
    inherit inputs;
    isDarwin = false;
    hostId = "wsl";
    rustToolchain = pkgs.rustc;
  };
}
