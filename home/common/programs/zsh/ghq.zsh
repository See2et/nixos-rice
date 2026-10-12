# Normalize GitHub owners without changing repository names or other hosts.
# Only interactive zsh calls are wrapped; `command ghq` bypasses this function.
ghq() {
  emulate -L zsh
  if [[ "$1" != get && "$1" != clone ]]; then
    command ghq "$@"
    return $?
  fi

  local arg default_host
  local -a args match mbegin mend
  local MATCH MBEGIN MEND
  local expect_value=0 options=1
  args=("$1")
  shift

  for arg in "$@"; do
    if (( expect_value )); then
      args+=("$arg")
      expect_value=0
      continue
    fi
    if (( options )); then
      case "$arg" in
        --) options=0; args+=("$arg"); continue ;;
        --branch|--vcs|--partial|-b)
          expect_value=1; args+=("$arg"); continue ;;
        --branch=*|--vcs=*|--partial=*|-b?*|--update|--shallow|--look|--silent|--no-recursive|--parallel|--bare|--clean-bare|--help|-h)
          args+=("$arg"); continue ;;
        -*)
          if [[ "$arg" =~ '^-[uplsP]+$' ]]; then
            args+=("$arg")
            continue
          fi
          # Unknown options may take values. Let ghq parse the original argv.
          command ghq "${args[1]}" "$@"
          return $?
          ;;
        *) options=0 ;;
      esac
    fi

    if [[ "$arg" =~ '^(https?://github[.]com/|ssh://git@github[.]com/|git@github[.]com:|github[.]com/)([[:alnum:]-]+)/([^/]+)$' ]]; then
      arg="${match[1]}${(L)match[2]}/${match[3]}"
    elif [[ "$arg" =~ '^([[:alnum:]-]+)/([^/]+)$' ]]; then
      # ghq uses GitHub only when defaultHost is absent or explicitly GitHub.
      default_host=$(command git config --get ghq.defaultHost 2>/dev/null)
      if [[ -z "$default_host" || "$default_host" == github.com ]]; then
        arg="${(L)match[1]}/${match[2]}"
      fi
    fi
    args+=("$arg")
  done

  command ghq "${args[@]}"
}
