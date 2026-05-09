# Darwin-specific Home Manager modules
# Settings ONLY for macOS/Darwin: Darwin-specific aliases, env vars, packages
# CRITICAL: No Linux-specific paths or tools
# Task 12: Darwin Home Manager Preservation

{
  config,
  isDarwin ? false,
  lib,
  ...
}:
{
  # Darwin-specific overrides and settings
  # These settings are applied ONLY when isDarwin = true

  # Ensure isDarwin is true for this module (safety check)
  assertions = [
    {
      assertion = isDarwin;
      message = "home/darwin module should only be imported when isDarwin = true";
    }
  ];

  # Darwin-specific environment variables (if needed in future)
  # home.sessionVariables = { };

  # Darwin-specific program configurations can be added here
  # Example: macOS-specific shell settings, tools, etc.

  xdg.configFile."karabiner/assets/complex_modifications/ghostty-ctrl-h-backspace.json" = {
    source = ./dotfiles/karabiner/ghostty-ctrl-h-backspace.json;
    force = true;
  };

  xdg.configFile."karabiner/assets/complex_modifications/capslock-to-ctrl.json" = {
    source = ./dotfiles/karabiner/capslock-to-ctrl.json;
    force = true;
  };

  # Docker/Colima mutate ~/.docker/config.json via temp-file + rename. Managing
  # that path as a Nix store symlink causes cross-device link failures, so keep
  # it as a normal writable file instead.
  home.activation.ensureWritableDockerConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dockerDir="${config.home.homeDirectory}/.docker"
        configFile="$dockerDir/config.json"

        mkdir -p "$dockerDir"

        if [ -L "$configFile" ]; then
          tmpFile="$(mktemp)"
          cp "$configFile" "$tmpFile"
          rm -f "$configFile"
          mv "$tmpFile" "$configFile"
        fi

        if [ ! -e "$configFile" ]; then
          cat > "$configFile" <<'EOF'
    {"cliPluginsExtraDirs":["/Applications/Docker.app/Contents/Resources/cli-plugins"]}
    EOF
        fi
  '';

  home.file."Library/Application Support/AquaSKK/BlacklistApps.plist" = {
    source = ./dotfiles/AquaSKK/BlacklistApps.plist;
    force = true;
  };

  imports = [
    ./rebuild.nix
    ./session.nix
    ./omniwm.nix
  ];
}
