{ pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withPython3 = true;
    withRuby = true;
  };

  # Python highlighting must work without a successful :TSInstall/network download.
  xdg.configFile."nvim/parser/python.so".source =
    "${pkgs.tree-sitter-grammars.tree-sitter-python}/parser";
}
