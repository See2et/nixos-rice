# Darwin host wiring
# GUARDRAILS:
# - Host file should only wire modules and identity
# - Darwin-specific logic belongs in modules/darwin/

{ inputs, pkgs, ... }:

{
  imports = [
    ../../modules/darwin
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  users.users.see2et.home = "/Users/see2et";
  system.primaryUser = "see2et";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.overwriteBackup = true;
  home-manager.users.see2et = {
    imports = [
      ../../home/common
      ../../home/darwin
    ];
    home.username = "see2et";
    home.homeDirectory = "/Users/see2et";
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
  };
  home-manager.extraSpecialArgs = {
    inherit inputs;
    isDarwin = true;
    hostId = "darwin";
    rustToolchain = pkgs.rustc;
  };

  system.stateVersion = 6;
}
