{ config, ... }:
{
  home.file.".local/bin/steam" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      unset VK_DRIVER_FILES VK_ICD_FILENAMES VK_LAYER_PATH VK_INSTANCE_LAYERS
      exec /run/current-system/sw/bin/steam "$@"
    '';
  };

  xdg = {
    desktopEntries = {
      steam = {
        name = "Steam";
        genericName = "Game platform";
        exec = "${config.home.homeDirectory}/.local/bin/steam %U";
        settings = {
          Path = "${config.home.homeDirectory}/.local/share/Steam/ubuntu12_32";
        };
        terminal = false;
        type = "Application";
        icon = "steam";
        categories = [
          "Network"
          "FileTransfer"
          "Game"
        ];
        mimeType = [
          "x-scheme-handler/steam"
          "x-scheme-handler/steamlink"
        ];
        startupNotify = true;
      };
    };

    configFile = {
      "wlxoverlay/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
    };

    dataFile = {
      "wallpapers/tori.webp".source = ../../assets/wallpapers/tori.webp;
    };
  };
}
