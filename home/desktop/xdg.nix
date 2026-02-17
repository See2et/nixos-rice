{ config, ... }:
{
  home.file.".local/bin/steam" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      steamvr_launch=0
      for arg in "$@"; do
        case "$arg" in
          *250820*|*SteamVR*|*steamvr*)
            steamvr_launch=1
            break
            ;;
        esac
      done

      if [ "$steamvr_launch" -eq 1 ]; then
        nvidia_icd="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.i686.json"
        export VK_DRIVER_FILES="$nvidia_icd"
        export VK_ICD_FILENAMES="$nvidia_icd"
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export DRI_PRIME=1
      else
        unset VK_DRIVER_FILES VK_ICD_FILENAMES
        unset __NV_PRIME_RENDER_OFFLOAD __VK_LAYER_NV_optimus __GLX_VENDOR_LIBRARY_NAME DRI_PRIME
      fi

      unset VK_LAYER_PATH VK_INSTANCE_LAYERS
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
