{ ... }:
{
  xdg.configFile = {
    "rofi/config.rasi".text = ''
      @theme "niri-archcraft-cyan"
    '';

    "rofi/themes/niri-archcraft-cyan.rasi".source = ./rofi/niri-archcraft-cyan.rasi;
  };
}
