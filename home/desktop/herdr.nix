{
  config,
  pkgs,
  inputs,
  ...
}:
let
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  helper = pkgs.writeShellApplication {
    name = "herdr-home";
    runtimeInputs = [
      herdr
      pkgs.python3
      pkgs.fzf
      pkgs.ghq
      pkgs.alacritty
      config.programs.niri.package
    ];
    text = ''
      export HERDR_BIN="${herdr}/bin/herdr"
      export HERDR_HOME_BIN="$0"
      exec python3 ${./scripts/herdr-home.py} "$@"
    '';
  };
  pickerWindow =
    command:
    pkgs.writeShellApplication {
      name = "herdr-${command}-window";
      runtimeInputs = [ pkgs.alacritty ];
      text = ''
        ${
          if command == "new" then
            "exec ${helper}/bin/herdr-home launch"
          else
            "exec alacritty -e ${helper}/bin/herdr-home ${command}"
        }
      '';
    };
in
{
  programs.zsh.shellAliases.hh = "herdr-home";

  home.packages = [
    herdr
    helper
    (pickerWindow "new")
    (pickerWindow "restore")
  ];
  xdg.configFile."herdr/config.toml".source = ./dotfiles/herdr/config.toml;
  xdg.desktopEntries.herdr-projects = {
    name = "Herdr: Projects (Create / Configure / Remove)";
    exec = "alacritty -e ${helper}/bin/herdr-home new --choose";
    terminal = false;
    categories = [ "Development" ];
  };
  xdg.desktopEntries.plain-terminal = {
    name = "Terminal: Plain Shell (without Herdr)";
    exec = "alacritty -e ${helper}/bin/herdr-home shell";
    terminal = false;
    categories = [ "Development" ];
  };
  xdg.desktopEntries.herdr-restore = {
    name = "Herdr: Restore Terminal";
    exec = "herdr-restore-window";
    terminal = false;
    categories = [ "Development" ];
  };
  xdg.desktopEntries.herdr-handoff = {
    name = "Herdr: Detach Local Views";
    exec = "${helper}/bin/herdr-home handoff";
    terminal = false;
    categories = [ "Development" ];
  };
}
