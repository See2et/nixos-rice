{ ... }:
{
  xdg = {
    configFile = {
      "wlxoverlay/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
    };

    dataFile = {
      "wallpapers/tori.webp".source = ../../assets/wallpapers/tori.webp;
    };
  };
}
