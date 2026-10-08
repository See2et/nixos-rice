{ inputs, pkgs, ... }:
{
  home.packages = with pkgs; [
    mosh
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Runs on the Mac, not inside SSH/Mosh. Keep Cmd+V for terminal text paste;
  # Ctrl+V lets the local Herdr client bridge clipboard images to the host.
  xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-mac-config.toml" {
    onboarding = false;
    keys = {
      prefix = "ctrl+b";
      remote_image_paste = "ctrl+v";
    };
    ui.mouse_capture = false;
  };

  programs.ssh = {
    settings.home = {
      HostName = "nixos.taile209b8.ts.net";
      User = "see2et";
      IdentitiesOnly = true;
    };
  };
}
