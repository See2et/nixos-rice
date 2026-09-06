#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)
FOLLOWER=${NIRI_PIP_FOLLOWER_BIN:-"${REPO_ROOT}/home/desktop/niri-pip-workspace-follower"}

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/niri-pip-follower.XXXXXX")
trap 'rm -rf -- "$TMP_ROOT"' EXIT HUP INT TERM

STATE_DIR=${TMP_ROOT}/state
FAKE_BIN=${TMP_ROOT}/bin
mkdir -p -- "$STATE_DIR" "$FAKE_BIN"

export FAKE_NIRI_STATE_DIR=$STATE_DIR
export NIRI_COMMAND=${FAKE_BIN}/niri
export NIRI_SOCKET=${STATE_DIR}/niri.sock
export SOCAT_COMMAND=${FAKE_BIN}/socat
export PATH="${FAKE_BIN}:${PATH}"

printf '#!%s\n' "$(command -v bash)" >"${FAKE_BIN}/niri"
cat >>"${FAKE_BIN}/niri" <<'EOF'
set -euo pipefail

state_dir=${FAKE_NIRI_STATE_DIR:?}
workspaces=${state_dir}/workspaces.json
windows=${state_dir}/windows.json
moves=${state_dir}/moves.log
completed_moves=${state_dir}/completed-moves.log
syncs=${state_dir}/syncs.log

replace_json() {
  local path=$1
  local filter=$2
  local temporary
  temporary=$(mktemp "${state_dir}/json.XXXXXX")
  jq "$filter" "$path" >"$temporary"
  mv -- "$temporary" "$path"
}

wait_for_moves() {
  local expected=$1
  local attempts=0
  while [[ $(wc -l <"$completed_moves") -lt $expected ]]; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 200 ]]; then
      printf 'timed out waiting for %s moves\n' "$expected" >&2
      cat "$moves" >&2
      cat "$syncs" >&2
      cat "$windows" >&2
      exit 1
    fi
    sleep 0.01
  done
}

wait_for_syncs() {
  local expected=$1
  local attempts=0
  while [[ $(wc -l <"$syncs") -lt $expected ]]; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 200 ]]; then
      printf 'timed out waiting for %s syncs\n' "$expected" >&2
      exit 1
    fi
    sleep 0.01
  done
}

if [[ $* == 'msg --json workspaces' ]]; then
  cat "$workspaces"
elif [[ $* == 'msg --json windows' ]]; then
  cat "$windows"
  printf 'sync\n' >>"$syncs"
elif [[ $* == 'msg --json event-stream' ]]; then
  replace_json "$workspaces" 'map(.is_focused = (.id == 73))'
  printf '%s\n' '{"WorkspacesChanged":{"workspaces":[{"id":41,"is_focused":false},{"id":73,"is_focused":true}]}}'
  wait_for_moves 5

  printf '%s\n' '{"WindowsChanged":{"windows":[]}}'
  wait_for_syncs 3

  printf '%s\n' '{"WorkspaceActivated":{"id":73,"focused":false}}'

  replace_json "$workspaces" 'map(.is_focused = (.id == 41))'
  printf '%s\n' '{"WorkspaceActivated":{"id":41,"focused":true}}'
  wait_for_moves 8

  replace_json "$windows" '. + [{"id":1005,"title":"Documentation","workspace_id":73}]'
  printf '%s\n' '{"WindowOpenedOrChanged":{"window":{"id":1005,"title":"Documentation","workspace_id":73}}}'

  replace_json "$windows" 'map(if .id == 1005 then .title = "Picture in Picture" else . end)'
  printf '%s\n' '{"WindowOpenedOrChanged":{"window":{"id":1005,"title":"Picture in Picture","workspace_id":73}}}'
  wait_for_moves 9

  replace_json "$windows" '. + [{"id":1006,"title":"Picture-in-Picture","workspace_id":73}]'
  printf '%s\n' '{"WindowOpenedOrChanged":{"window":{"id":1006,"title":"Picture-in-Picture","workspace_id":73}}}'
  wait_for_moves 10

  replace_json "$windows" 'map(if .id == 1001 then .workspace_id = 73 else . end)'
  printf '%s\n' '{"WindowsChanged":{"windows":[]}}'
  wait_for_moves 11

  printf '%s\n' '{"WindowsChanged":{"windows":[]}}'
  wait_for_syncs 8
else
  printf 'unexpected niri arguments: %s\n' "$*" >&2
  exit 64
fi
EOF
chmod +x "${FAKE_BIN}/niri"

printf '#!%s\n' "$(command -v bash)" >"${FAKE_BIN}/socat"
cat >>"${FAKE_BIN}/socat" <<'EOF'
set -euo pipefail

state_dir=${FAKE_NIRI_STATE_DIR:?}
windows=${state_dir}/windows.json
moves=${state_dir}/moves.log
completed_moves=${state_dir}/completed-moves.log

[[ $# -eq 2 && $1 == - && $2 == "UNIX-CONNECT:${NIRI_SOCKET:?}" ]]
if ! IFS= read -r request; then
  printf 'request must end with a newline\n' >&2
  exit 1
fi
if IFS= read -r extra || [[ -n ${extra-} ]]; then
  printf 'expected exactly one JSON request line\n' >&2
  exit 1
fi

jq -e '
  .Action.MoveWindowToWorkspace as $move
  | (keys == ["Action"])
    and (($move | keys | sort) == ["focus", "reference", "window_id"])
    and (($move.reference | keys) == ["Id"])
    and ($move.window_id | type == "number")
    and ($move.reference.Id | type == "number")
    and ($move.focus == false)
' >/dev/null <<<"$request"

window_id=$(jq -er '.Action.MoveWindowToWorkspace.window_id' <<<"$request")
workspace_id=$(jq -er '.Action.MoveWindowToWorkspace.reference.Id' <<<"$request")
printf '%s\n' "$request" >>"$moves"

temporary=$(mktemp "${state_dir}/json.XXXXXX")
jq --argjson window_id "$window_id" --argjson workspace_id "$workspace_id" \
  'map(if .id == $window_id then .workspace_id = $workspace_id else . end)' \
  "$windows" >"$temporary"
mv -- "$temporary" "$windows"
printf '%s\n' "$window_id" >>"$completed_moves"
reply=${FAKE_NIRI_REPLY-'{"Ok":"Handled"}'}
printf '%s\n' "$reply"
EOF
chmod +x "${FAKE_BIN}/socat"

reset_state() {
  cat >"${STATE_DIR}/workspaces.json" <<'EOF'
[
  {"id":41,"idx":1,"is_focused":true},
  {"id":73,"idx":2,"is_focused":false}
]
EOF
  cat >"${STATE_DIR}/windows.json" <<'EOF'
[
  {"id":1001,"title":"Picture-in-Picture","workspace_id":9},
  {"id":1002,"title":"Picture in Picture","workspace_id":41},
  {"id":1003,"title":"Picture in picture","workspace_id":17},
  {"id":1004,"title":"Browser","workspace_id":9}
]
EOF
  : >"${STATE_DIR}/moves.log"
  : >"${STATE_DIR}/completed-moves.log"
  : >"${STATE_DIR}/syncs.log"
}

assert_moves() {
  local expected=$1
  local actual
  actual=$(<"${STATE_DIR}/moves.log")
  if [[ $actual != "$expected" ]]; then
    printf 'unexpected move commands\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

reset_state
bash "$FOLLOWER" --sync-once
assert_moves $'{"Action":{"MoveWindowToWorkspace":{"window_id":1001,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1003,"reference":{"Id":41},"focus":false}}}'

reset_state
if FAKE_NIRI_REPLY='{"Err":"Rejected"}' bash "$FOLLOWER" --sync-once; then
  printf 'expected follower to reject a non-Handled IPC reply\n' >&2
  exit 1
fi

reset_state
bash "$FOLLOWER"
assert_moves $'{"Action":{"MoveWindowToWorkspace":{"window_id":1001,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1003,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1001,"reference":{"Id":73},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1002,"reference":{"Id":73},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1003,"reference":{"Id":73},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1001,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1002,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1003,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1005,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1006,"reference":{"Id":41},"focus":false}}}\n{"Action":{"MoveWindowToWorkspace":{"window_id":1001,"reference":{"Id":41},"focus":false}}}'

printf 'niri-pip-workspace-follower: ok\n'
