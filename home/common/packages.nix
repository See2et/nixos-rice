# Common packages shared across all platforms
# Platform-specific packages (wl-clipboard, xclip, libnotify) belong in home/linux
{
  pkgs,
  rustToolchain,
  inputs,
  opencodePackage,
  ...
}:
let
  pencil-cli = pkgs.callPackage ../../packages/pencil-cli { };
  python-debug = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  home.packages =
    (with pkgs; [
      python-debug
      (writeShellScriptBin "python-debugpy" ''
        exec "${python-debug}/bin/python" "$@"
      '')
      basedpyright
      ruff
      zsh
      gcc
      unzip
      cargo
      biome
      rust-analyzer
      lua-language-server
      tre-command
      lsd
      nixfmt
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
      jq
      fd
      ffmpeg
      tinymist
      typst
      websocat
      fzf
      markdownlint-cli2
      (lib.hiPrio textlint)
      yubikey-manager
      wget
      openssl
      pkg-config
    ])
    ++ [
      rustToolchain
      inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex
      opencodePackage
      pencil-cli
    ];
}
