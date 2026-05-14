{ ... }:
{
  fonts.fontDir.enable = true;

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
