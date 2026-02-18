{ lib, config, ... }:
{
  config = lib.mkIf config.programs.niri.enable (
    lib.mkMerge [
      {
        systemd.user.services.waybar.Unit = {
          After = [ "desktop-wallpaper-startup.service" ];
          Wants = [ "desktop-wallpaper-startup.service" ];
        };
      }

      (lib.mkIf config.services.swaync.enable {
        systemd.user.services.swaync.Unit = {
          After = [ "desktop-wallpaper-startup.service" ];
          Wants = [ "desktop-wallpaper-startup.service" ];
        };
      })
    ]
  );
}
