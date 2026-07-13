{ pkgs }:

pkgs.writeShellApplication {
  name = "trim-nix-generations";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.nix
  ];
  text = ''
    warn() {
      printf 'warning: could not trim Nix generations for %s: %s\n' "$1" "$2" >&2
    }

    trim_profile() {
      local profile="$1"
      local current_target
      local current_generation
      local generation_output
      local generation
      local kept_generation
      local retained
      local -a generations=()
      local -a keep=()
      local -a delete=()

      if [[ ! -L "$profile" ]]; then
        return 0
      fi

      if ! current_target="$(readlink "$profile")"; then
        warn "$profile" "cannot resolve current generation"
        return 0
      fi

      if [[ ! "$current_target" =~ -([0-9]+)-link$ ]]; then
        warn "$profile" "current generation has an unexpected link target"
        return 0
      fi
      current_generation="''${BASH_REMATCH[1]}"

      if ! generation_output="$(nix-env --profile "$profile" --list-generations)"; then
        warn "$profile" "cannot list generations"
        return 0
      fi

      mapfile -t generations < <(
        printf '%s\n' "$generation_output" \
          | awk '$1 ~ /^[0-9]+$/ { print $1 }' \
          | sort --numeric-sort --reverse
      )

      if (( ''${#generations[@]} <= 5 )); then
        return 0
      fi

      keep+=("$current_generation")
      for generation in "''${generations[@]}"; do
        if [[ "$generation" != "$current_generation" ]] && (( ''${#keep[@]} < 5 )); then
          keep+=("$generation")
        fi
      done

      for generation in "''${generations[@]}"; do
        retained=false
        for kept_generation in "''${keep[@]}"; do
          if [[ "$generation" == "$kept_generation" ]]; then
            retained=true
            break
          fi
        done

        if [[ "$retained" == false ]]; then
          delete+=("$generation")
        fi
      done

      if (( ''${#delete[@]} > 0 )); then
        if ! nix-env --profile "$profile" --delete-generations "''${delete[@]}"; then
          warn "$profile" "generation deletion failed"
        fi
      fi
    }

    for profile in "$@"; do
      trim_profile "$profile"
    done
  '';
}
