# Common packages shared across all platforms
# Platform-specific packages (wl-clipboard, xclip, libnotify) belong in home/linux
{
  pkgs,
  rustToolchain,
  inputs,
  ...
}:
{
  home.packages =
    (with pkgs; [
      python3
      zsh
      gcc
      unzip
      cargo
      rust-analyzer
      tre-command
      lsd
      nixfmt-rfc-style
      nixd
      gh
      ghq
      lazygit
      zenn-cli
      peco
      zoxide
      nodejs_24
      bun
      pnpm
      yarn
      deno
      uv
      fastfetch
      tree-sitter
      yt-dlp
      ripgrep
      ffmpeg
      fzf
      markdownlint-cli2
      yubikey-manager
      wget
    ])
    ++ [
      rustToolchain
      inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex-node
      inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    ];
}
