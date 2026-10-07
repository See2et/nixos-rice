# Invoked by writeShellApplication (and directly by the isolated behavior tests).
set -euo pipefail
umask 077

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/desktop-storage-notification"
mkdir -p "$state_dir"
exec 9>"$state_dir/lock"
flock -n 9 || exit 0

# Use bytes available to an ordinary user, excluding ext4's reserved space.
available="$(df --block-size=1 --output=avail / | tail -n 1)"
available="${available//[[:space:]]/}"
if [[ ! "$available" =~ ^[0-9]+$ ]]; then
  printf 'Cannot determine root filesystem available bytes: %s\n' "$available" >&2
  exit 1
fi

previous=0
if [[ -f "$state_dir/severity" ]]; then
  read -r previous < "$state_dir/severity" || previous=0
  case "$previous" in
    0|1|2) ;;
    *) previous=0 ;;
  esac
fi

severity=0
if (( available < 20 * 1024 * 1024 * 1024 )); then
  severity=2
elif (( available < 50 * 1024 * 1024 * 1024 )); then
  severity=1
fi

# Remember the highest notified severity until full recovery (>=50 GiB).
# Failed notification delivery leaves state unchanged so the next check retries.
if (( severity > previous )); then
  urgency=normal
  title="ディスクの空き容量が少なくなっています"
  if (( severity == 2 )); then
    urgency=critical
    title="ディスクの空き容量が危険な水準です"
  fi
  readable="$(numfmt --to=iec-i --suffix=B "$available")"
  notify-send --app-name="ディスク容量" --urgency="$urgency" \
    "$title" "/ の空き容量は $readable です。不要なNixストアやキャッシュを確認してください。"
elif (( severity != 0 )); then
  exit 0
fi

temporary="$(mktemp "$state_dir/severity.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
printf '%s\n' "$severity" > "$temporary"
mv -f "$temporary" "$state_dir/severity"
