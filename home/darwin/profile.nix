# Canonical Darwin Home Manager profile shared by darwinConfigurations and
# compatibility-only homeConfigurations.
{ darwinUser, ... }:
{
  imports = [
    ../common
    ./.
  ];

  home.username = darwinUser.name;
  home.homeDirectory = darwinUser.home;
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
