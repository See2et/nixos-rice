{ lib, ... }:
{
  xdg.enable = true;

  home.activation.migrateRecursiveConfigDirs = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    migrate_recursive_dir() {
      local path="$1"

      if [ -L "$path" ]; then
        local resolved
        resolved="$(readlink -f "$path" || true)"
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
  };
}
