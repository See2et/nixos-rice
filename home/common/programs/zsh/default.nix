# Common zsh configuration
{ pkgs, lib, ... }:
{
  imports = [
    ./abbreviations.nix
    ./plugins.nix
  ];

  programs.zsh = {
    enable = true;

    initContent =
      let
        zshConfigEarlyInit = lib.mkOrder 500 ''
          export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi

          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
        '';
        zshConfig = lib.mkOrder 1000 ''
          export ABBR_QUIET=1
          ABBR_SET_EXPANSION_CURSOR=1

          typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

          eval "$(zoxide init zsh)"
          eval "$(${pkgs.uv}/bin/uv generate-shell-completion zsh)"

          function fzf-ghq() {
            local selected
            selected=$(ghq list --full-path \
              | fzf \
                --ansi \
                --height 90% \
                --layout=reverse \
                --border --border-label ' 📂 Repository ' --border-label-pos=2 \
                --color 'label:blue,header:italic:dim' \
                --prompt 'REPO> ' \
                --header $'Enter: cd │ Ctrl-/: toggle preview' \
                --preview "
                  printf '\\033[1;34m━━━ Repository Info ━━━\\033[0m\\n';
                  git -C {} log --oneline --graph --date=short --color=always \
                    --pretty='format:%C(auto)%cd %h%d %s' -20 2>/dev/null
                " \
                --preview-window 'right,50%,border-left' \
                --bind 'ctrl-/:change-preview-window(down,40%|hidden|right,50%)' \
                --bind 'ctrl-k:up,ctrl-j:down' \
            ) || return
            [[ -n "$selected" ]] && cd "$selected"
          }
          abbr -S gp='fzf-ghq'

          function fzf-ghq-widget() {
            if [[ -n "$WIDGET" ]]; then
              zle -I
              fzf-ghq
              zle reset-prompt
            else
              fzf-ghq
            fi
          }
          zle -N fzf-ghq-widget
          bindkey "^[r" fzf-ghq-widget

          function peco-git-switch() {
            local sel branch
            sel=$(
              git for-each-ref --format='%(refname:short)' refs/heads \
              | peco --prompt "BRANCH> " --query "$LBUFFER" --layout=bottom-up --print-query \
              | tail -n 1
            ) || return

            [[ -z "$sel" ]] && return
            branch="$sel"

            if git show-ref --verify --quiet "refs/heads/$branch"; then
              git switch "$branch"
            else
              git switch -c "$branch"
            fi
          }
          abbr -S gsp="peco-git-switch"

          function peco-history() {
            local selected_command=$(fc -l -n 1 | tail -300 | awk '!seen[$0]++ { lines[++count] = $0 } END { for (i = count; i >= 1; i--) print lines[i] }' | peco --prompt "HISTORY>" --layout=bottom-up)

            if [ -n "$selected_command" ]; then
              print -s "$selected_command"
              echo "Executing: $selected_command"
              eval "$selected_command"
            fi
          }
          abbr -S hp="peco-history"

          function peco-zoxide() {
            local dir
            dir=$(zoxide query -l | peco --prompt "DIR> " --layout=bottom-up)
            [[ -n "$dir" ]] && cd "$dir"
          }
          abbr -S zp="peco-zoxide"

          function __fzf_gwt_resolve_repo() {
            local git_common_dir main_repo ghq_root repo_path remote_url

            git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || return 1

            if [[ "$git_common_dir" == ".git" ]]; then
              main_repo=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
            else
              main_repo="''${git_common_dir%/.git}"
            fi

            ghq_root=$(ghq root 2>/dev/null) || ghq_root=""
            if [[ -n "$ghq_root" && "$main_repo" == "$ghq_root/"* ]]; then
              repo_path="''${main_repo#"$ghq_root/"}"
            else
              remote_url=$(git -C "$main_repo" remote get-url origin 2>/dev/null) || remote_url=""
              if [[ -n "$remote_url" ]]; then
                repo_path=$(printf "%s" "$remote_url" | sed -E 's#(git@|https://)##; s#:#/#; s#\\.git$##')
              else
                repo_path=$(basename "$main_repo")
              fi
            fi

            printf "%s\n%s" "$main_repo" "$HOME/worktrees/$repo_path"
          }

          function __fzf_gwt_list() {
            local main_repo="$1" worktree_repo_root="$2"
            local branches branch wt_path

            branches=$(git -C "$main_repo" for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's#^origin/##' | sort -u)

            while IFS= read -r branch; do
              [[ -z "$branch" ]] && continue
              wt_path="$worktree_repo_root/''${branch//\//-}"
              if [[ -d "$wt_path" ]]; then
                printf "\033[32m●\033[0m\t%-40s\t\033[2m%s\033[0m\n" "$branch" "$wt_path"
              else
                printf "\033[90m○\033[0m\t%-40s\t\n" "$branch"
              fi
            done <<< "$branches"
          }

          function fzf-git-worktree() {
            local main_repo worktree_repo_root repo_info
            local result query key selected branch wt_path
            local fzf_default_opts

            repo_info=$(__fzf_gwt_resolve_repo) || {
              print -u2 "fzf-git-worktree: not in a git repository"
              return 1
            }
            main_repo=$(printf "%s" "$repo_info" | sed -n '1p')
            worktree_repo_root=$(printf "%s" "$repo_info" | sed -n '2p')
            mkdir -p "$worktree_repo_root"

            fzf_default_opts="$FZF_DEFAULT_OPTS"
            if [[ "$fzf_default_opts" == *"--layout=bottom-up"* ]]; then
              fzf_default_opts="''${fzf_default_opts//--layout=bottom-up/--layout=reverse}"
            fi

            local _gwt_preview _gwt_delete _gwt_reload

            _gwt_preview="
              branch=\$(echo {2} | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*\$//');
              wt_dir=\$(echo \$branch | tr / -);
              wt_path=$worktree_repo_root/\$wt_dir;
              if [ -d \$wt_path ]; then
                printf '\\033[1;34m━━━ Worktree Status ━━━\\033[0m\\n';
                git -C \$wt_path status --short --branch --color=always 2>/dev/null;
                echo;
              fi;
              printf '\\033[1;34m━━━ Recent Commits ━━━\\033[0m\\n';
              git -C $main_repo log --oneline --graph --date=short --color=always \
                --pretty='format:%C(auto)%cd %h%d %s' \$branch -- 2>/dev/null | head -40
            "

            _gwt_delete="
              branch=\$(echo {2} | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*\$//');
              wt_dir=\$(echo \$branch | tr / -);
              wt_path=$worktree_repo_root/\$wt_dir;
              [ -d \$wt_path ] && git -C $main_repo worktree remove \$wt_path 2>/dev/null
            "

            _gwt_reload="
              git -C $main_repo for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin \
              | sed 's#^origin/##' | sort -u | while IFS= read -r b; do
                [ -z \"\$b\" ] && continue;
                wp=$worktree_repo_root/\$(echo \$b | tr / -);
                if [ -d \$wp ]; then
                  printf '\\033[32m●\\033[0m\\t%-40s\\t\\033[2m%s\\033[0m\\n' \"\$b\" \$wp;
                else
                  printf '\\033[90m○\\033[0m\\t%-40s\\t\\n' \"\$b\";
                fi;
              done
            "

            result=$(__fzf_gwt_list "$main_repo" "$worktree_repo_root" \
              | FZF_DEFAULT_OPTS="$fzf_default_opts" fzf \
                --ansi \
                --height 90% \
                --layout=reverse \
                --border --border-label ' 🌴 Worktree ' --border-label-pos=2 \
                --color 'label:green,header:italic:dim' \
                --prompt 'WORKTREE> ' \
                --header $'Enter: switch │ Ctrl-A: new branch │ Ctrl-D: delete │ Ctrl-/: toggle preview' \
                --delimiter=$'\t' \
                --with-nth=1,2 \
                --preview "$_gwt_preview" \
                --preview-window 'right,50%,border-left' \
                --bind 'ctrl-/:change-preview-window(down,40%|hidden|right,50%)' \
                --bind 'ctrl-k:up,ctrl-j:down' \
                --bind "ctrl-d:execute-silent($_gwt_delete)+reload($_gwt_reload)" \
                --expect=ctrl-a \
                --print-query \
            ) || return

            query=$(printf "%s\n" "$result" | sed -n '1p')
            key=$(printf "%s\n" "$result" | sed -n '2p')
            selected=$(printf "%s\n" "$result" | sed -n '3p' | awk -F $'\t' '{print $2}' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

            case "$key" in
              ctrl-a)
                branch="$query"
                [[ -z "$branch" ]] && return
                ;;
              *)
                branch="$selected"
                [[ -z "$branch" ]] && return
                ;;
            esac

            wt_path="$worktree_repo_root/''${branch//\//-}"

            if [[ -d "$wt_path" ]]; then
              cd "$wt_path"
            else
              if git -C "$main_repo" show-ref --verify --quiet "refs/heads/$branch"; then
                git -C "$main_repo" worktree add "$wt_path" "$branch" || return
              else
                git -C "$main_repo" worktree add -b "$branch" "$wt_path" || return
              fi
              cd "$wt_path"
            fi
          }
          abbr -S gw="fzf-git-worktree"

          function fzf-git-worktree-widget() {
            if [[ -n "$WIDGET" ]]; then
              zle -I
              fzf-git-worktree
              zle reset-prompt
            else
              fzf-git-worktree
            fi
          }
          zle -N fzf-git-worktree-widget
          bindkey "^[b" fzf-git-worktree-widget
        '';
      in
      lib.mkMerge [
        zshConfigEarlyInit
        zshConfig
      ];
  };
}
