{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  voxtypePackage = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
in
{
  imports = [ inputs.voxtype.homeManagerModules.default ];

  config = lib.mkIf config.programs.niri.enable {
    programs.voxtype = {
      enable = true;
      package = voxtypePackage;
      engine = "whisper";
      model.name = "small";
      service.enable = true;

      settings = {
        state_file = "auto";

        hotkey.enabled = false;

        whisper = {
          language = "ja";
          translate = false;
          on_demand_loading = false;
        };

        audio.feedback = {
          enabled = true;
          theme = "subtle";
          volume = 0.7;
        };

        output = {
          mode = "type";
          fallback_to_clipboard = true;
          type_delay_ms = 0;
          notification = {
            on_recording_start = true;
            on_recording_stop = true;
            on_transcription = true;
          };
        };

        osd.enabled = false;
      };
    };

    programs.niri.settings.binds."Mod+R" = {
      repeat = false;
      action.spawn = [
        (lib.getExe voxtypePackage)
        "record"
        "toggle"
      ];
    };
  };
}
