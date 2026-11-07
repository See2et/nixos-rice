{ pkgs }:
let
  discord = pkgs.discord.override {
    source = builtins.fromJSON (builtins.readFile ./discord-source.json);
  };
  moduleManifest = builtins.toJSON (
    builtins.mapAttrs (_: version: { installedVersion = version; }) discord.moduleVersions
  );

  # Match upstream staging: Discord checks real paths against the module root.
  stageModules = pkgs.writeShellScript "discord-stage-modules" ''
    store_modules="$1"
    modules_dir="''${DISCORD_USER_DATA_DIR-''${XDG_CONFIG_HOME:-$HOME/.config}}/discord/${discord.version}/modules"
    rm -rf "$modules_dir"
    mkdir -p "$(dirname "$modules_dir")"
    ln -s "$store_modules" "$modules_dir"
  '';
in
discord.override {
  unwrappedDiscord = discord.unwrappedDiscord.overrideAttrs (old: {
    inherit stageModules;
    passthru = (old.passthru or { }) // {
      inherit stageModules;
    };
    postInstall = (old.postInstall or "") + ''
      echo ${pkgs.lib.escapeShellArg moduleManifest} > "$out/opt/Discord/modules/installed.json"
      mkdir -p "$out/opt/Discord/modules/pending"
    '';
  });
}
