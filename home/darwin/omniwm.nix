{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkBinding = id: binding: {
    inherit id binding;
  };

  omniwmApp = pkgs.fetchzip {
    url = "https://github.com/BarutSRB/OmniWM/releases/download/v0.4.6/OmniWM-v0.4.6.zip";
    hash = "sha256-coAo0RvUWIViGWUikJkpBc7ruRLY56C+Bqger7op9pw=";
  };

  omniwmBundle = pkgs.runCommandLocal "omniwm-bundle" { } ''
    mkdir -p "$out/OmniWM.app"
    cp -R ${omniwmApp}/Contents "$out/OmniWM.app/"
    find "$out/OmniWM.app" -name '._*' -delete
  '';

  hotkeyBindings = builtins.toJSON [
    (mkBinding "focus.left" "Option+H")
    (mkBinding "focus.down" "Option+J")
    (mkBinding "focus.up" "Option+K")
    (mkBinding "focus.right" "Option+L")

    (mkBinding "move.left" "Option+Shift+H")
    (mkBinding "move.down" "Option+Shift+J")
    (mkBinding "move.up" "Option+Shift+K")
    (mkBinding "move.right" "Option+Shift+L")

    (mkBinding "switchWorkspace.0" "Option+1")
    (mkBinding "switchWorkspace.1" "Option+2")
    (mkBinding "switchWorkspace.2" "Option+3")
    (mkBinding "switchWorkspace.3" "Option+4")
    (mkBinding "switchWorkspace.4" "Option+5")
    (mkBinding "switchWorkspace.5" "Option+6")
    (mkBinding "switchWorkspace.6" "Option+7")
    (mkBinding "switchWorkspace.7" "Option+8")
    (mkBinding "switchWorkspace.8" "Option+9")

    (mkBinding "moveToWorkspace.0" "Option+Shift+1")
    (mkBinding "moveToWorkspace.1" "Option+Shift+2")
    (mkBinding "moveToWorkspace.2" "Option+Shift+3")
    (mkBinding "moveToWorkspace.3" "Option+Shift+4")
    (mkBinding "moveToWorkspace.4" "Option+Shift+5")
    (mkBinding "moveToWorkspace.5" "Option+Shift+6")
    (mkBinding "moveToWorkspace.6" "Option+Shift+7")
    (mkBinding "moveToWorkspace.7" "Option+Shift+8")
    (mkBinding "moveToWorkspace.8" "Option+Shift+9")

    (mkBinding "focusColumn.0" "Control+Option+1")
    (mkBinding "focusColumn.1" "Control+Option+2")
    (mkBinding "focusColumn.2" "Control+Option+3")
    (mkBinding "focusColumn.3" "Control+Option+4")
    (mkBinding "focusColumn.4" "Control+Option+5")
    (mkBinding "focusColumn.5" "Control+Option+6")
    (mkBinding "focusColumn.6" "Control+Option+7")
    (mkBinding "focusColumn.7" "Control+Option+8")
    (mkBinding "focusColumn.8" "Control+Option+9")

    (mkBinding "focusPrevious" "Option+Tab")
    (mkBinding "workspaceBackAndForth" "Control+Option+Tab")

    (mkBinding "focusMonitorNext" "Control+Command+Tab")
    (mkBinding "focusMonitorLast" "Control+Command+`")

    (mkBinding "toggleFullscreen" "Option+Return")
    (mkBinding "balanceSizes" "Option+Shift+B")
    (mkBinding "toggleColumnTabbed" "Option+T")
    (mkBinding "cycleColumnWidthBackward" "Option+Comma")
    (mkBinding "cycleColumnWidthForward" "Option+Period")
    (mkBinding "toggleColumnFullWidth" "Option+Shift+F")
    (mkBinding "moveColumn.left" "Control+Option+Shift+H")
    (mkBinding "moveColumn.right" "Control+Option+Shift+L")

    (mkBinding "openCommandPalette" "Control+Space")
    (mkBinding "openMenuAnywhere" "Control+Option+M")
    (mkBinding "toggleQuakeTerminal" "Option+`")
    (mkBinding "toggleOverview" "Option+Shift+O")
    (mkBinding "toggleWorkspaceLayout" "Option+Shift+L")
  ];

  omniwmSettingsPlist =
    pkgs.runCommandLocal "omniwm-settings.plist"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
          hotkeyBindingsB64="$(printf '%s' ${lib.escapeShellArg hotkeyBindings} | ${pkgs.openssl}/bin/openssl base64 -A)"

          {
            printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
            printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
            printf '%s\n' '<plist version="1.0">'
        printf '%s\n' '<dict>'
        printf '%s\n' '  <key>settings.hotkeysEnabled</key>'
        printf '%s\n' '  <true/>'
        printf '%s\n' '  <key>settings.ipcEnabled</key>'
        printf '%s\n' '  <true/>'
            printf '%s\n' '  <key>settings.hotkeyBindings</key>'
            printf '%s\n' '  <data>'
            printf '%s\n' "$hotkeyBindingsB64"
            printf '%s\n' '  </data>'
            printf '%s\n' '</dict>'
            printf '%s\n' '</plist>'
          } > "$out"
      '';
in
{
  home.file."Applications/Nix Apps/OmniWM.app".source = "${omniwmBundle}/OmniWM.app";

  home.file."Library/LaunchAgents/com.barut.omniwm.plist".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>com.barut.omniwm</string>
      <key>ProgramArguments</key>
      <array>
        <string>/Users/see2et/Applications/Nix Apps/OmniWM.app/Contents/MacOS/OmniWM</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>KeepAlive</key>
      <true/>
      <key>ProcessType</key>
      <string>Interactive</string>
    </dict>
    </plist>
  '';

  home.activation.omniwmPreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    prefs_dir="${config.home.homeDirectory}/Library/Preferences"
    prefs_file="$prefs_dir/com.barut.OmniWM.plist"

    ${pkgs.coreutils}/bin/mkdir -p "$prefs_dir"
    ${pkgs.coreutils}/bin/cp ${lib.escapeShellArg omniwmSettingsPlist} "$prefs_file"
    ${pkgs.coreutils}/bin/chmod 644 "$prefs_file"
  '';
}
