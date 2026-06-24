# Darwin-specific Home Manager modules
# Settings ONLY for macOS/Darwin: Darwin-specific aliases, env vars, packages
# CRITICAL: No Linux-specific paths or tools
# Task 12: Darwin Home Manager Preservation

{
  config,
  isDarwin ? false,
  lib,
  pkgs,
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

  xdg.configFile."karabiner/assets/complex_modifications/input-source-shortcuts.json" = {
    source = ./dotfiles/karabiner/input-source-shortcuts.json;
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

  home.activation.syncKarabinerInputSourceShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    karabinerConfig="${config.home.homeDirectory}/.config/karabiner/karabiner.json"
    karabinerRuleAsset="${config.home.homeDirectory}/.config/karabiner/assets/complex_modifications/input-source-shortcuts.json"

    if [ ! -f "$karabinerRuleAsset" ]; then
      exit 0
    fi

    mkdir -p "$(dirname "$karabinerConfig")"

    ${pkgs.python3}/bin/python3 - <<'PY'
import json
from pathlib import Path

config_path = Path("${config.home.homeDirectory}/.config/karabiner/karabiner.json")
asset_path = Path("${config.home.homeDirectory}/.config/karabiner/assets/complex_modifications/input-source-shortcuts.json")

if config_path.exists():
    config = json.loads(config_path.read_text())
else:
    config = {}

profiles = config.setdefault("profiles", [])
if not profiles:
    profiles.append({"name": "Default profile", "selected": True})

profile = next((p for p in profiles if p.get("selected")), profiles[0])
complex_modifications = profile.setdefault("complex_modifications", {})
existing_rules = complex_modifications.setdefault("rules", [])

asset = json.loads(asset_path.read_text())
new_rules = asset.get("rules", [])
managed_descriptions = {rule.get("description") for rule in new_rules}

complex_modifications["rules"] = [
    rule for rule in existing_rules if rule.get("description") not in managed_descriptions
] + new_rules

config_path.write_text(json.dumps(config, indent=4) + "\n")
PY
  '';

  home.file."Library/Application Support/AquaSKK/BlacklistApps.plist" = {
    source = ./dotfiles/AquaSKK/BlacklistApps.plist;
    force = false;
  };

  imports = [
    ./rebuild.nix
    ./session.nix
    ./omniwm.nix
    ./remote-dev.nix
  ];
}
