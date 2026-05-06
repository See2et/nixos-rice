{ lib, pkgs, ... }:
{
  fonts.fontDir.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.symbols-only
    texlivePackages.haranoaji
    source-han-sans
    source-han-serif
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
        "Harano Aji Mincho"
        "Noto Serif CJK JP"
        "Noto Color Emoji"
        "serif"
      ];
      sansSerif = [
        "Harano Aji Gothic"
        "FiraCode Nerd Font"
        "Noto Sans CJK JP"
        "Noto Sans CJK KR"
        "Noto Sans CJK SC"
        "Noto Color Emoji"
        "sans-serif"
      ];
      monospace = [
        "FiraCode Nerd Font"
        "Harano Aji Gothic"
        "Noto Sans CJK JP"
        "Noto Color Emoji"
        "monospace"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
