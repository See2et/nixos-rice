{ inputs, pkgs, ... }:
let
  # Share the desktop's declarative settings without importing Linux HM modules.
  desktopConfig = builtins.fromTOML (builtins.readFile ../desktop/dotfiles/herdr/config.toml);
  macConfig = desktopConfig // {
    # Local custom commands are not forwarded by --remote. The desktop popup
    # uses herdr-home, which is Linux-only; use Herdr's native picker instead.
    keys = builtins.removeAttrs desktopConfig.keys [ "command" ] // {
      workspace_picker = "prefix+w";
      remote_image_paste = "ctrl+v";
    };
  };
in
{
  home.packages = with pkgs; [
    mosh
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Runs on the Mac, not inside SSH/Mosh. Keep Cmd+V for terminal text paste;
  # Ctrl+V lets the local Herdr client bridge clipboard images to the host.
  xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-mac-config.toml" macConfig;

  programs.zsh.shellAliases.h = "herdr --remote home --remote-keybindings server";

  programs.ssh = {
    settings.home = {
      HostName = "nixos.taile209b8.ts.net";
      User = "see2et";
      IdentitiesOnly = true;
    };
  };
}
