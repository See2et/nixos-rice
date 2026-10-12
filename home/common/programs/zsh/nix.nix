# Interactive Nix command routing: Skills updates and the managed development shell.
{ config, lib, pkgs, ... }:
{
  # Python and scripts still invoke the real executable, bypassing this function.
  programs.zsh.initContent = lib.mkAfter ''
    function nix() {
      if [[ "''${1-}" == flake && "''${2-}" == update ]]; then
        command skills-update "$@"
      else
        # Nix rewrites SHELL to Bash inside dev shells; use the managed Zsh instead.
        # Explicit commands and other nix subcommands still pass through unchanged.
        ${lib.getExe pkgs.nix-your-shell} ${lib.getExe config.programs.zsh.package} nix -- "$@"
      fi
    }
  '';
}
