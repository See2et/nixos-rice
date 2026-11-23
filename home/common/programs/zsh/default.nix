# Common zsh configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./abbreviations.nix
    ./plugins.nix
    ./nix.nix
  ];

  home.file.".p10k.zsh".source = ./p10k.zsh;

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;

    shellAliases = {
      "opencode-strict" = "OMO_PROFILE=strict opencode";
    };

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

                    function skk-ctrl-j-noop() {
                      zle redisplay
                    }
                    zle -N skk-ctrl-j-noop
                    bindkey '^J' skk-ctrl-j-noop

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

          function fzf-git-worktree() {
            local target record
            git rev-parse --git-common-dir >/dev/null 2>&1 || {
              print -u2 "fzf-git-worktree: not in a git repository"
              return 1
            }
            IFS= read -r -d $'\0' target < <(
              git worktree list --porcelain -z |
                while IFS= read -r -d $'\0' record; do
                  if [[ "$record" == "worktree "* ]]; then
                    printf '%s\0' "''${record#worktree }"
                  fi
                done |
                fzf --read0 --print0 --prompt 'WORKTREE> '
            ) || return
            [[ -d "$target" ]] || {
              print -u2 "fzf-git-worktree: unavailable worktree: $target"
              return 1
            }
            cd -- "$target"
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

          function git-codex-commit() {
            local diff prompt msg tmp_output tmp_error cc_pattern

                      git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
                        print -u2 "git-codex-commit: not in a git repository"
                        return 1
                      }

                      git diff --cached --quiet && {
                        print -u2 "git-codex-commit: no staged changes"
                        return 1
                      }

                      diff=$(git diff --cached --unified=3 --no-color)
                      if [[ -z "$diff" ]]; then
                        print -u2 "git-codex-commit: failed to read staged diff"
                        return 1
                      fi

                      prompt=$(cat <<'EOF'
          You write exactly one Conventional Commit subject line for the staged git diff.
          Rules:
          - Output exactly one line and nothing else.
          - Format: type(scope): subject OR type: subject.
          - Allowed types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
          - Use imperative mood, lowercase type, no trailing period, max 72 chars.
          - No markdown, no quotes, no code fences.
          EOF
          )

            tmp_output=$(mktemp) || {
              print -u2 "git-codex-commit: failed to create temp file"
              return 1
            }

            tmp_error=$(mktemp) || {
              rm -f "$tmp_output"
              print -u2 "git-codex-commit: failed to create error file"
              return 1
            }

            printf "%s\n\n--- STAGED DIFF ---\n%s\n" "$prompt" "$diff" \
            | codex exec --color never --output-last-message "$tmp_output" --model gpt-5.6-luna -s read-only - >/dev/null 2>"$tmp_error" || {
              cat "$tmp_error" >&2
              rm -f "$tmp_output" "$tmp_error"
              print -u2 "git-codex-commit: codex failed"
              return 1
            }

            msg=$(sed -n '/[^[:space:]]/ { p; q; }' "$tmp_output")
            rm -f "$tmp_output" "$tmp_error"

            msg=$(printf "%s" "$msg" | tr -d '\r' | sed -E 's/^`+//; s/`+$//; s/^[[:space:]]+//; s/[[:space:]]+$//')

            cc_pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?:[[:space:]]+.+$'
            if [[ ! "$msg" =~ "$cc_pattern" ]]; then
              print -u2 "git-codex-commit: invalid conventional commit subject from codex"
              print -u2 "generated: $msg"
              return 1
            fi

                      git commit -m "$msg"
                    }
                    abbr -S gx='git-codex-commit'
        '';
      in
      lib.mkMerge [
        zshConfigEarlyInit
        zshConfig
        (lib.mkAfter (builtins.readFile ./ghq.zsh))
      ];
  };
}
