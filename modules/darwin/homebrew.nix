# Declarative Homebrew via nix-homebrew + nix-darwin

{
  config,
  inputs,
  darwinUser,
  ...
}:

{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = darwinUser.name;
    autoMigrate = true;
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    taps = builtins.attrNames config.nix-homebrew.taps;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    brews = [
      "mas"
      "p7zip"
      "colima"
    ];
    casks = [
      "alacritty"
      "anki"
      "discord"
      "discord@canary"
      # Docker Desktop provides the Compose v2 plugin on darwin.
      # Docker CLI discovery is configured via home/darwin/default.nix.
      "docker"
      "figma"
      "ghostty"
      "godot"
      "google-chrome"
      "kitty"
      "karabiner-elements"
      "mpv"
      "obs"
      "obsidian"
      "rowboat"
      "slack"
      "wezterm"
      "yubico-authenticator"
      "zen"
      "zoom"
      "raycast"
      "notion"
      "notion-calendar"
      "balenaetcher"
      "chatgpt"
      "opencloud"
      "parsec"
      "yt-music"
      "prismlauncher"
    ];
    masApps = {
      Kindle = 302584613;
      LINE = 539883307;
    };
  };
}
