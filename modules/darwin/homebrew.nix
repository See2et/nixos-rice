# Declarative Homebrew via nix-homebrew + nix-darwin

{ config, inputs, ... }:

{
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "see2et";
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
      "p7zip"
    ];
    casks = [
      "alacritty"
      "anki"
      "discord"
      "discord@canary"
      "figma"
      "ghostty"
      "godot"
      "google-chrome"
      "kitty"
      "karabiner-elements"
      "mpv"
      "obs"
      "obsidian"
      "slack"
      "wezterm"
      "yubico-authenticator"
      "zen"
      "zoom"
      "raycast"
    ];
    masApps = { };
  };
}
