{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # imports = [ ~/.config/home-manager/flake.nix ];
  imports = [ inputs.catppuccin.homeModules.catppuccin ];
  home.stateVersion = "25.05";


  home.sessionVariables = {
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    EDITOR = "nvim";

  };

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    home-manager
  ];
}
