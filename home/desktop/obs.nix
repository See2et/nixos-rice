{
  config,
  lib,
  pkgs,
  ...
}:
{
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    videos = "${config.home.homeDirectory}/Videos";
  };

  home.activation.obsRecordingPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    obs_recording_dir="${config.xdg.userDirs.videos}/OBS"
    profiles_dir="${config.home.homeDirectory}/.config/obs-studio/basic/profiles"

    ${pkgs.coreutils}/bin/mkdir -p "$obs_recording_dir"

    if [ -d "$profiles_dir" ]; then
      for basic_ini in "$profiles_dir"/*/basic.ini; do
        [ -f "$basic_ini" ] || continue
        ${pkgs.gnused}/bin/sed -i \
          -e "s|^FilePath=.*$|FilePath=$obs_recording_dir|" \
          -e "s|^RecFilePath=.*$|RecFilePath=$obs_recording_dir|" \
          -e "s|^FFFilePath=.*$|FFFilePath=$obs_recording_dir|" \
          "$basic_ini"
      done
    fi
  '';
}
