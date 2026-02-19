# WSL-specific home files
# Includes WSL notifier and WSL-only configuration files
# CRITICAL: Only for WSL, must NOT appear in desktop or darwin
{ ... }:
{
  home.file = {
    ".config/opencode/opencode-notifier.json".source = ./dotfiles/opencode/opencode-notifier.json;
    ".local/bin/opencode-wsl-notify" = {
      source = ./bin/opencode-wsl-notify;
      executable = true;
    };
  };
}
