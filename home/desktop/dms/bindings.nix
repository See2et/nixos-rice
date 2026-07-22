{ dms }:
{
  "Ctrl+Space".action.spawn = [
    dms
    "ipc"
    "call"
    "spotlight"
    "toggle"
  ];
  "Mod+Escape".action.spawn = [
    dms
    "ipc"
    "call"
    "powermenu"
    "toggle"
  ];
  "Mod+N".action.spawn = [
    dms
    "ipc"
    "call"
    "notifications"
    "toggle"
  ];
  "Mod+Ctrl+Comma".action.spawn = [
    dms
    "ipc"
    "call"
    "settings"
    "focusOrToggle"
  ];
  "Mod+Alt+L".action.spawn = [
    dms
    "ipc"
    "call"
    "lock"
    "lock"
  ];
  "Mod+V".action.spawn = [
    dms
    "ipc"
    "call"
    "clipboard"
    "toggle"
  ];
  "Mod+E".action.spawn = [
    dms
    "ipc"
    "call"
    "spotlight"
    "openQuery"
    ":"
  ];
  "Mod+Shift+W".action.spawn = [
    dms
    "ipc"
    "call"
    "settings"
    "focusOrToggleWith"
    "wallpaper"
  ];
  "Mod+Ctrl+W".action.spawn = [
    dms
    "ipc"
    "call"
    "wallpaper"
    "next"
  ];
  "Mod+Ctrl+Shift+W".action.spawn = [
    dms
    "ipc"
    "call"
    "wallpaper"
    "prev"
  ];
  "Mod+Ctrl+Alt+W".action.spawn = [ "dms-wallpaper-random" ];
  "Mod+S".action.spawn = [ "dms-screenshot-all" ];
  "Mod+Shift+S".action.spawn = [ "dms-screenshot-region" ];
  "Mod+Ctrl+S".action.spawn = [ "dms-screenshot-window" ];
  "Mod+Alt+S".action.spawn = [ "dms-screenshot-full" ];
  "XF86AudioRaiseVolume" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "audio"
      "increment"
      "3"
    ];
  };
  "XF86AudioLowerVolume" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "audio"
      "decrement"
      "3"
    ];
  };
  "XF86AudioMute" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "audio"
      "mute"
    ];
  };
  "XF86AudioMicMute" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "mic"
      "mute"
    ];
  };
  "XF86MonBrightnessUp" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "brightness"
      "increment"
      "5"
      ""
    ];
  };
  "XF86MonBrightnessDown" = {
    allow-when-locked = true;
    action.spawn = [
      dms
      "ipc"
      "call"
      "brightness"
      "decrement"
      "5"
      ""
    ];
  };
}
