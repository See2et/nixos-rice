{ pkgs, ... }:

let
  storageNotification = pkgs.writeShellApplication {
    name = "desktop-storage-notification";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/storage-notification.sh;
  };
in
{
  # Bind to the graphical session, not default.target: this user has linger enabled.
  systemd.user.services.desktop-storage-notification = {
    Unit = {
      Description = "Notify about low root filesystem space";
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${storageNotification}/bin/desktop-storage-notification";
      TimeoutStartSec = 30;
    };
  };

  systemd.user.timers.desktop-storage-notification = {
    Unit = {
      Description = "Check root filesystem space during the desktop session";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Timer = {
      OnActiveSec = "1min";
      OnUnitActiveSec = "15min";
      Unit = "desktop-storage-notification.service";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
