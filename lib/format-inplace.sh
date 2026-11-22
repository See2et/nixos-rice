# Preserve ownership of group-writable files; nixfmt's atomic replacement tries to chown them.
formatted=$(mktemp)
trap 'rm -f "$formatted"' EXIT

for file in "$@"; do
  format < "$file" > "$formatted"
  if ! cmp -s "$file" "$formatted"; then
    cat "$formatted" > "$file"
  fi
done
