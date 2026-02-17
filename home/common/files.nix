# Common home files shared across all platforms
# WSL-specific files (opencode-notifier.json, opencode-wsl-notify) belong in home/wsl
{ ... }:
{
  home.file = {
    ".gitconfig".source = ../../.gitconfig;
    ".p10k.zsh".source = ../../.p10k.zsh;
    ".codex/config.toml".source = ../../codex/config.toml;
    ".codex/AGENTS.md".source = ../../codex/AGENTS.md;
    ".codex/github-mcp.sh" = {
      source = ../../codex/github-mcp.sh;
      executable = true;
    };
    "yubikey-setup.sh" = {
      source = ../../yubikey-setup.sh;
      executable = true;
    };
    ".config/opencode/opencode.jsonc".source = ../../opencode/opencode.jsonc;
    ".config/opencode/oh-my-opencode.jsonc".source = ../../opencode/oh-my-opencode.jsonc;
    ".config/opencode/AGENTS.md".source = ../../opencode/AGENTS.md;
    ".config/opencode/themes/tokyonight-transparent.json".source =
      ../../opencode/themes/tokyonight-transparent.json;
  };
}
