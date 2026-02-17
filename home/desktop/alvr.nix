{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.activation.alvrForceSoftwareEncoding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    session_file="${config.home.homeDirectory}/.config/alvr/session.json"

    if [ -f "$session_file" ]; then
      tmp_file="$(${pkgs.coreutils}/bin/mktemp)"

      if ${pkgs.jq}/bin/jq '
        .openvr_config.force_sw_encoding = true
        | .session_settings.video.encoder_config.software.force_software_encoding = true
      ' "$session_file" > "$tmp_file"; then
        ${pkgs.coreutils}/bin/mv "$tmp_file" "$session_file"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp_file"
      fi
    fi
  '';
}
