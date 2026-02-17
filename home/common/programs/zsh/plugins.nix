# Common zsh plugins
{ ... }:
{
  programs.zsh.antidote = {
    enable = true;
    plugins = [
      "ohmyzsh/ohmyzsh"
      "zsh-users/zsh-autosuggestions"
      "zsh-users/zsh-syntax-highlighting"
      "romkatv/powerlevel10k"
      "Tarrasch/zsh-bd"
    ];
  };
}
