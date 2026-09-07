{
  config,
  pkgs,
  ...
}:
{
  home.file.".local/bin/thunar-zip-extract" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      for archive in "$@"; do
        [ -f "$archive" ] || continue

        archive_basename="$(${pkgs.coreutils}/bin/basename "$archive")"
        archive_dir="$(${pkgs.coreutils}/bin/dirname "$archive")"
        target_name="''${archive_basename%.zip}"
        target_name="''${target_name%.ZIP}"

        if [ -z "$target_name" ] || [ "$target_name" = "$archive_basename" ]; then
          target_name="''${archive_basename%.*}"
        fi

        target_path="$archive_dir/$target_name"

        if [ -e "$target_path" ]; then
          suffix=1
          while [ -e "$target_path ($suffix)" ]; do
            suffix=$((suffix + 1))
          done
          target_path="$target_path ($suffix)"
        fi

        ${pkgs.coreutils}/bin/mkdir -p "$target_path"

        if ! ${pkgs.unzip}/bin/unzip -qq "$archive" -d "$target_path"; then
          ${pkgs.coreutils}/bin/rm -rf "$target_path"
        fi
      done
    '';
  };

  xdg = {
    mimeApps = {
      enable = true;
      associations.added = {
        "application/zip" = [ "thunar-zip-extract.desktop" ];
        "application/x-zip" = [ "thunar-zip-extract.desktop" ];
        "application/x-zip-compressed" = [ "thunar-zip-extract.desktop" ];
        "multipart/x-zip" = [ "thunar-zip-extract.desktop" ];
        "image/avif" = [ "swayimg-visible.desktop" ];
        "image/gif" = [ "swayimg-visible.desktop" ];
        "image/jpeg" = [ "swayimg-visible.desktop" ];
        "image/png" = [ "swayimg-visible.desktop" ];
        "image/webp" = [ "swayimg-visible.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "application/xhtml+xml" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "text/html" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/about" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/figma" = [
          "figma-url.desktop"
        ];
        "x-scheme-handler/http" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/https" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/steam" = [
          "steam.desktop"
        ];
        "x-scheme-handler/steamlink" = [
          "steam.desktop"
        ];
        "x-scheme-handler/unknown" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
      };
      defaultApplications = {
        "application/zip" = [ "thunar-zip-extract.desktop" ];
        "application/x-zip" = [ "thunar-zip-extract.desktop" ];
        "application/x-zip-compressed" = [ "thunar-zip-extract.desktop" ];
        "multipart/x-zip" = [ "thunar-zip-extract.desktop" ];
        "image/avif" = [ "swayimg-visible.desktop" ];
        "image/gif" = [ "swayimg-visible.desktop" ];
        "image/jpeg" = [ "swayimg-visible.desktop" ];
        "image/png" = [ "swayimg-visible.desktop" ];
        "image/webp" = [ "swayimg-visible.desktop" ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "application/xhtml+xml" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "text/html" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/about" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/figma" = [
          "figma-url.desktop"
        ];
        "x-scheme-handler/http" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/https" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
        "x-scheme-handler/steam" = [
          "steam.desktop"
        ];
        "x-scheme-handler/slack" = [
          "slack.desktop"
        ];
        "x-scheme-handler/steamlink" = [
          "steam.desktop"
        ];
        "x-scheme-handler/unknown" = [
          "zen-twilight.desktop"
          "zen-url.desktop"
        ];
      };
    };

    desktopEntries = {
      thunar-zip-extract = {
        name = "ZIP Extractor";
        genericName = "Archive extractor";
        comment = "Extract ZIP archives into a new folder";
        exec = "${config.home.homeDirectory}/.local/bin/thunar-zip-extract %F";
        terminal = false;
        type = "Application";
        categories = [ "Utility" ];
        mimeType = [
          "application/zip"
          "application/x-zip"
          "application/x-zip-compressed"
          "multipart/x-zip"
        ];
        startupNotify = false;
      };

      swayimg-visible = {
        name = "Swayimg";
        genericName = "Image viewer";
        comment = "Image viewer for Sway/Wayland";
        exec = "/etc/profiles/per-user/${config.home.username}/bin/swayimg %F";
        terminal = false;
        type = "Application";
        icon = "swayimg";
        categories = [
          "Graphics"
          "Viewer"
        ];
        mimeType = [
          "image/avif"
          "image/gif"
          "image/jpeg"
          "image/png"
          "image/webp"
        ];
        startupNotify = false;
      };

      zen-url = {
        name = "Zen Browser URL Handler";
        genericName = "Web Browser";
        exec = "/etc/profiles/per-user/${config.home.username}/bin/zen-twilight --name zen-twilight %U";
        terminal = false;
        type = "Application";
        icon = "zen-twilight";
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeType = [
          "application/xhtml+xml"
          "text/html"
          "x-scheme-handler/about"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/unknown"
        ];
        startupNotify = true;
      };

      figma-url = {
        name = "Figma URL Handler";
        genericName = "Design Tool";
        exec = "/etc/profiles/per-user/${config.home.username}/bin/figma-linux %U";
        terminal = false;
        type = "Application";
        icon = "figma-linux";
        categories = [
          "Graphics"
        ];
        mimeType = [
          "x-scheme-handler/figma"
        ];
        startupNotify = true;
      };

    };

  };
}
