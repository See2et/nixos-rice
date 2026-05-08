{ lib, pkgs, ... }:
{
  xdg.enable = true;

  home.activation.migrateRecursiveConfigDirs = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    readlink_bin="${pkgs.coreutils}/bin/readlink"

    migrate_recursive_dir() {
      local path="$1"

      if [ -L "$path" ]; then
        local resolved
        resolved="$($readlink_bin -f "$path" || true)"
        if [ -n "$resolved" ] && [ "''${resolved#/nix/store/}" != "$resolved" ]; then
          run mv "$path" "''${path}.hm-pre-recursive.$(date +%Y%m%d-%H%M%S)"
        fi
      fi
    }

    migrate_recursive_dir "$HOME/.config/nvim"
    migrate_recursive_dir "$HOME/.config/zellij"
  '';

  xdg.configFile = {
    "nvim" = {
      source = ./dotfiles/nvim;
      recursive = true;
      force = true;
    };
    "zellij" = {
      source = ./dotfiles/zellij;
      recursive = true;
      force = true;
    };
    "ghostty/config" = {
      source = ./dotfiles/ghostty/config;
      force = true;
    };
  };
}
