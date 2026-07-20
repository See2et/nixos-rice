#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "${SCRIPT_DIR}/.." && pwd)

DIAGNOSE_BIN=${STEAMVR_DIAGNOSE_BIN:-"${REPO_ROOT}/home/desktop/vr/tools/steamvr-diagnose"}
RUNTIME_ENV_BIN=${STEAMVR_RUNTIME_ENV_BIN:-"${REPO_ROOT}/home/desktop/vr/tools/steamvr-runtime-env"}
SELECT_OPENXR_BIN=${STEAMVR_SELECT_OPENXR_BIN:-"${REPO_ROOT}/home/desktop/vr/tools/steamvr-select-openxr"}
ALVR_QUALITY_PROFILE_BIN=${ALVR_QUALITY_PROFILE_BIN:-"${REPO_ROOT}/home/desktop/vr/tools/alvr-quality-profile"}

DIAGNOSE_CMD=(bash "${DIAGNOSE_BIN}")
RUNTIME_ENV_CMD=(bash "${RUNTIME_ENV_BIN}")
SELECT_OPENXR_CMD=(bash "${SELECT_OPENXR_BIN}")
ALVR_QUALITY_PROFILE_CMD=(bash "${ALVR_QUALITY_PROFILE_BIN}")

JQ_WRAPPER_DIR=
BINUTILS_WRAPPER_DIR=
VALID_RUNTIME_ELF_SOURCE=

ensure_jq() {
  if command -v jq >/dev/null 2>&1; then
    return 0
  fi

  command -v nix >/dev/null 2>&1 || fail "jq: missing from PATH"

  JQ_WRAPPER_DIR=$(mktemp -d "${TMP_ROOT}/jq.XXXXXX")
  jq_path=$(nix shell nixpkgs#jq -c bash -lc 'command -v jq')
  ln -s -- "${jq_path}" "${JQ_WRAPPER_DIR}/jq"
  PATH="${JQ_WRAPPER_DIR}:${PATH}"
}

ensure_readelf() {
  if command -v readelf >/dev/null 2>&1; then
    return 0
  fi

  command -v nix >/dev/null 2>&1 || fail "readelf: missing from PATH"

  BINUTILS_WRAPPER_DIR=$(mktemp -d "${TMP_ROOT}/binutils.XXXXXX")
  readelf_path=$(nix shell nixpkgs#binutils -c bash -lc 'command -v readelf')
  ln -s -- "${readelf_path}" "${BINUTILS_WRAPPER_DIR}/readelf"
  PATH="${BINUTILS_WRAPPER_DIR}:${PATH}"
}

TMP_ROOT=

cleanup() {
  if [ -n "${TMP_ROOT:-}" ] && [ -d "${TMP_ROOT}" ]; then
    chmod -R u+w -- "${TMP_ROOT}" 2>/dev/null || true
    rm -rf -- "${TMP_ROOT}"
  fi
}

trap cleanup EXIT HUP INT TERM

fail() {
  printf '%b\n' "$*" >&2
  exit 1
}

assert_contains() {
  haystack=$1
  needle=$2
  label=$3
  case ${haystack} in
    *"${needle}"*) ;;
    *) fail "${label}: expected to contain '${needle}'" ;;
  esac
}

assert_eq() {
  expected=$1
  actual=$2
  label=$3
  if [ "${actual}" != "${expected}" ]; then
    fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

assert_file_exists() {
  path=$1
  [ -e "${path}" ] || fail "expected file to exist: ${path}"
}

assert_file_not_exists() {
  path=$1
  [ ! -e "${path}" ] || fail "expected file to be absent: ${path}"
}

assert_file_contents() {
  path=$1
  expected=$2
  label=$3
  actual=$(<"${path}")
  assert_eq "${expected}" "${actual}" "${label}"
}

assert_symlink_target() {
  path=$1
  expected=$2
  [ -L "${path}" ] || fail "expected symlink: ${path}"
  target=$(readlink -- "${path}")
  assert_eq "${expected}" "${target}" "symlink target ${path}"
}

assert_not_set() {
  value=${1-}
  label=$2
  if [ -n "${value}" ]; then
    fail "${label}: expected unset"
  fi
}

run_expect_success() {
  label=$1
  shift

  stdout_file=$(mktemp "${TMP_ROOT}/stdout.XXXXXX")
  stderr_file=$(mktemp "${TMP_ROOT}/stderr.XXXXXX")

  if ! "$@" >"${stdout_file}" 2>"${stderr_file}"; then
    stdout=$(<"${stdout_file}")
    stderr=$(<"${stderr_file}")
    rm -f -- "${stdout_file}" "${stderr_file}"
    fail "${label}: expected success\nstdout:\n${stdout}\nstderr:\n${stderr}"
  fi

  RUN_STDOUT=$(<"${stdout_file}")
  RUN_STDERR=$(<"${stderr_file}")
  rm -f -- "${stdout_file}" "${stderr_file}"
}

run_expect_failure() {
  label=$1
  needle=$2
  shift 2

  stdout_file=$(mktemp "${TMP_ROOT}/stdout.XXXXXX")
  stderr_file=$(mktemp "${TMP_ROOT}/stderr.XXXXXX")

  if "$@" >"${stdout_file}" 2>"${stderr_file}"; then
    stdout=$(<"${stdout_file}")
    stderr=$(<"${stderr_file}")
    rm -f -- "${stdout_file}" "${stderr_file}"
    fail "${label}: expected failure\nstdout:\n${stdout}\nstderr:\n${stderr}"
  fi

  RUN_STDOUT=$(<"${stdout_file}")
  RUN_STDERR=$(<"${stderr_file}")
  rm -f -- "${stdout_file}" "${stderr_file}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "${needle}" "${label} stderr"
}

setup_root() {
  TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/steamvr-tools.XXXXXX")
}

prepare_case_home() {
  case_name=$1
  HOME_DIR=${TMP_ROOT}/${case_name}/home
  STEAM_ROOT=${HOME_DIR}/.local/share/Steam
  STEAMVR_LIBRARY=${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so
  STEAMVR_MANIFEST_PATH=${STEAM_ROOT}/steamapps/common/SteamVR/steamxr_linux64.json
  STEAMVR_MANIFEST_LIBRARY=${STEAM_ROOT}/steamapps/common/SteamVR/runtime/steamxr_loader.so
  XDG_CONFIG_HOME=${HOME_DIR}/.config
  OPENXR_DIR=${XDG_CONFIG_HOME}/openxr/1
  WORK_DIR=${TMP_ROOT}/${case_name}/work
  MANIFEST_DIR=${TMP_ROOT}/${case_name}/manifests
  PROBE_DIR=${TMP_ROOT}/${case_name}/probe

  mkdir -p -- "${HOME_DIR}" "${WORK_DIR}" "${MANIFEST_DIR}" "${PROBE_DIR}" "${OPENXR_DIR}"

  export HOME=${HOME_DIR}
  export XDG_CONFIG_HOME
}

write_alvr_quality_session() {
  session_path=${XDG_CONFIG_HOME}/alvr/session.json
  mkdir -p -- "$(dirname -- "${session_path}")"
  cat >"${session_path}" <<'EOF'
{
  "session_settings": {
    "video": {
      "bitrate": {
        "mode": {
          "ConstantMbps": 35,
          "variant": "ConstantMbps"
        }
      },
      "preferred_codec": {
        "variant": "Hevc"
      },
      "preferred_fps": 72.0,
      "transcoding_view_resolution": {
        "Absolute": {
          "width": 1856,
          "height": {
            "set": false
          }
        },
        "variant": "Absolute"
      },
      "emulated_headset_view_resolution": {
        "Absolute": {
          "width": 1856,
          "height": {
            "set": false
          }
        },
        "variant": "Absolute"
      },
      "foveated_encoding": {
        "enabled": true,
        "content": {
          "center_size_x": 0.6,
          "center_size_y": 0.55,
          "edge_ratio_x": 2.0,
          "edge_ratio_y": 2.5
        }
      },
      "clientside_post_processing": {
        "enabled": false
      }
    }
  }
}
EOF
}

prepare_mock_curl() {
  MOCK_CURL_DIR=${TMP_ROOT}/mock-curl
  ALVR_CURL_BODY=${TMP_ROOT}/alvr-curl-body.json
  ALVR_CURL_ARGS=${TMP_ROOT}/alvr-curl-args.txt
  mkdir -p -- "${MOCK_CURL_DIR}"
  printf '#!%s\n' "$(command -v bash)" >"${MOCK_CURL_DIR}/curl"
  cat >>"${MOCK_CURL_DIR}/curl" <<'EOF'
set -euo pipefail

: "${ALVR_CURL_BODY:?}"
: "${ALVR_CURL_ARGS:?}"
printf '%s\n' "$@" >"${ALVR_CURL_ARGS}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --data)
      printf '%s\n' "$2" >"${ALVR_CURL_BODY}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n ${ALVR_CURL_RESULT_SESSION:-} ]]; then
  cp -- "${ALVR_CURL_RESULT_SESSION}" "${ALVR_SESSION_PATH}"
fi
EOF
  chmod +x -- "${MOCK_CURL_DIR}/curl"
}

write_runtime_manifest() {
  manifest_path=$1
  library_path=$2
  mkdir -p -- "$(dirname -- "${manifest_path}")"
  cat >"${manifest_path}" <<EOF
{
  "file_format_version": "1.0.0",
  "runtime": {
    "library_path": "${library_path}"
  }
}
EOF
}

write_malformed_manifest() {
  manifest_path=$1
  mkdir -p -- "$(dirname -- "${manifest_path}")"
  printf '%s\n' '{"file_format_version": "1.0.0", "runtime": {' >"${manifest_path}"
}

write_manifest_with_version() {
  manifest_path=$1
  version=$2
  library_path=$3
  mkdir -p -- "$(dirname -- "${manifest_path}")"
  cat >"${manifest_path}" <<EOF
{
  "file_format_version": "${version}",
  "runtime": {
    "library_path": "${library_path}"
  }
}
EOF
}

write_magic_only_fake_elf_file() {
  target_path=$1
  mkdir -p -- "$(dirname -- "${target_path}")"
  printf '\177ELFminimal-test-payload\n' >"${target_path}"
}

readelf_header_output() {
  LC_ALL=C readelf -h --wide "$1" 2>/dev/null
}

readelf_full_output() {
  LC_ALL=C readelf -h -l -d --wide "$1" 2>&1
}

assert_readelf_rejected() {
  path=$1
  label=$2

  if output=$(readelf_header_output "${path}"); then
    fail "${label}: expected readelf rejection\noutput:\n${output}"
  fi
}

assert_readelf_contains() {
  path=$1
  needle=$2
  label=$3

  output=$(readelf_header_output "${path}") || fail "${label}: expected readelf to succeed"
  assert_contains "${output}" "${needle}" "${label} readelf header"
}

assert_readelf_full_status_and_contains() {
  path=$1
  expected_status=$2
  needle=$3
  label=$4

  output=$(readelf_full_output "${path}")
  status=$?
  if [ "${status}" -ne "${expected_status}" ]; then
    fail "${label}: expected readelf status ${expected_status}, got ${status}\noutput:\n${output}"
  fi
  assert_contains "${output}" "${needle}" "${label} readelf output"
}

valid_runtime_elf_source() {
  candidate_is_valid_runtime_elf() {
    candidate_path=$1

    [ -n "${candidate_path}" ] || return 1
    [ -f "${candidate_path}" ] || return 1

    if output=$(readelf_full_output "${candidate_path}"); then
      if [ "${output#*Class:                             ELF64}" != "${output}" ] \
        && [ "${output#*Machine:                           Advanced Micro Devices X86-64}" != "${output}" ] \
        && [ "${output#*Type:                              DYN (Shared object file)}" != "${output}" ] \
        && [ "${output#*  LOAD           }" != "${output}" ] \
        && [ "${output#*  DYNAMIC        }" != "${output}" ] \
        && [ "${output#*Dynamic section at offset}" != "${output}" ]; then
        return 0
      fi
    fi

    return 1
  }

  interpreter_from_binary() {
    binary_path=$1
    output=$(readelf_full_output "${binary_path}" 2>/dev/null || true)
    case ${output} in
      *"[Requesting program interpreter: "*"]"*)
        interpreter_path=${output#*\[Requesting program interpreter: }
        interpreter_path=${interpreter_path%%]*}
        printf '%s\n' "${interpreter_path}"
        ;;
    esac
  }

  if [ -n "${VALID_RUNTIME_ELF_SOURCE}" ] && [ -f "${VALID_RUNTIME_ELF_SOURCE}" ]; then
    printf '%s\n' "${VALID_RUNTIME_ELF_SOURCE}"
    return 0
  fi

  for candidate in \
    "$(command -v jq 2>/dev/null || true)" \
    "$(interpreter_from_binary "$(command -v jq 2>/dev/null || true)")" \
    "$(command -v readelf 2>/dev/null || true)" \
    "$(interpreter_from_binary "$(command -v readelf 2>/dev/null || true)")"; do
    if candidate_is_valid_runtime_elf "${candidate}"; then
      VALID_RUNTIME_ELF_SOURCE=${candidate}
      printf '%s\n' "${VALID_RUNTIME_ELF_SOURCE}"
      return 0
    fi
  done

  fail "no parseable ELF64 x86-64 ET_DYN fixture source found in PATH"
}

copy_valid_runtime_elf_file() {
  target_path=$1
  mkdir -p -- "$(dirname -- "${target_path}")"
  cp -- "$(valid_runtime_elf_source)" "${target_path}"
  chmod u+w -- "${target_path}"
}

write_bytes_at_offset() {
  target_path=$1
  offset=$2
  shift 2
  byte_string=

  for byte_value in "$@"; do
    byte_string+="$(printf '\\%03o' "${byte_value}")"
  done

  printf '%b' "${byte_string}" | dd of="${target_path}" bs=1 seek="${offset}" conv=notrunc status=none
}

write_elf32_variant_file() {
  target_path=$1
  copy_valid_runtime_elf_file "${target_path}"
  write_bytes_at_offset "${target_path}" 4 1
}

write_wrong_machine_variant_file() {
  target_path=$1
  copy_valid_runtime_elf_file "${target_path}"
  write_bytes_at_offset "${target_path}" 18 3 0
}

write_non_et_dyn_variant_file() {
  target_path=$1
  copy_valid_runtime_elf_file "${target_path}"
  write_bytes_at_offset "${target_path}" 16 2 0
}

write_truncated_variant_file() {
  target_path=$1
  copy_valid_runtime_elf_file "${target_path}"
  truncate -s 64 -- "${target_path}"
}

make_env_probe() {
  probe_path=$1
  capture_path=$2
  cat >"${probe_path}" <<'EOF'
set -eu
printf '%s\n' "${XR_RUNTIME_JSON-}" > "$1"
EOF
}

prepare_fake_steam_install() {
  steamvr_dir=$(dirname -- "${STEAMVR_LIBRARY}")
  mkdir -p -- "${steamvr_dir}"
  copy_valid_runtime_elf_file "${STEAMVR_LIBRARY}"

  mkdir -p -- "$(dirname -- "${STEAMVR_MANIFEST_LIBRARY}")"
  write_runtime_manifest "${STEAMVR_MANIFEST_PATH}" "runtime/steamxr_loader.so"
  copy_valid_runtime_elf_file "${STEAMVR_MANIFEST_LIBRARY}"
}

capture_permission_state() {
  target_path=$1
  find "${target_path}" -printf '%m %y %p\n' | sort
}

capture_path_state() {
  target_path=$1
  stat -c '%a %A %F %u %g %s %n' -- "${target_path}"
}

case_diagnose_missing_steam() {
  prepare_case_home diagnose-missing
  rm -rf -- "${STEAM_ROOT}"

  run_expect_success diagnose_missing_steam "${DIAGNOSE_CMD[@]}"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "missing Steam" "diagnose missing Steam"
}

case_diagnose_read_only_steam() {
  prepare_case_home diagnose-read-only
  prepare_fake_steam_install
  chmod -R a-w -- "${STEAM_ROOT}"

  before=$(find "${HOME_DIR}" -maxdepth 4 -type f | sort)
  before_steam_root_state=$(capture_path_state "${STEAM_ROOT}")
  before_library_state=$(capture_path_state "${STEAMVR_LIBRARY}")
  before_perms=$(capture_permission_state "${STEAM_ROOT}")
  run_expect_success diagnose_read_only_steam "${DIAGNOSE_CMD[@]}"
  after=$(find "${HOME_DIR}" -maxdepth 4 -type f | sort)
  after_steam_root_state=$(capture_path_state "${STEAM_ROOT}")
  after_library_state=$(capture_path_state "${STEAMVR_LIBRARY}")
  after_perms=$(capture_permission_state "${STEAM_ROOT}")
  assert_eq "${before}" "${after}" "diagnose must not mutate read-only Steam"
  assert_eq "${before_steam_root_state}" "${after_steam_root_state}" "diagnose must not change Steam directory state"
  assert_eq "${before_library_state}" "${after_library_state}" "diagnose must not change SteamVR library state"
  assert_eq "${before_perms}" "${after_perms}" "diagnose must not change read-only Steam permissions"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "read-only" "diagnose read-only"
}

case_diagnose_reads_steamxr_manifest_and_resolves_runtime_library() {
  prepare_case_home diagnose-steamxr-manifest
  prepare_fake_steam_install
  rm -f -- "${STEAMVR_LIBRARY}"

  before=$(find "${HOME_DIR}" -maxdepth 6 -type f | sort)
  before_manifest_state=$(capture_path_state "${STEAMVR_MANIFEST_PATH}")
  before_runtime_state=$(capture_path_state "${STEAMVR_MANIFEST_LIBRARY}")

  run_expect_success diagnose_reads_steamxr_manifest_and_resolves_runtime_library "${DIAGNOSE_CMD[@]}"

  after=$(find "${HOME_DIR}" -maxdepth 6 -type f | sort)
  after_manifest_state=$(capture_path_state "${STEAMVR_MANIFEST_PATH}")
  after_runtime_state=$(capture_path_state "${STEAMVR_MANIFEST_LIBRARY}")

  assert_eq "${before}" "${after}" "diagnose must not mutate SteamVR files"
  assert_eq "${before_manifest_state}" "${after_manifest_state}" "diagnose must not change steamxr_linux64.json"
  assert_eq "${before_runtime_state}" "${after_runtime_state}" "diagnose must not change resolved runtime library"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "manifest valid" "diagnose steamxr manifest"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "resolved runtime library present" "diagnose steamxr runtime library"
}

case_diagnose_reports_generic_selector_when_arch_specific_absent() {
  prepare_case_home diagnose-generic-selector
  prepare_fake_steam_install

  generic_manifest=${MANIFEST_DIR}/generic-runtime.json
  write_runtime_manifest "${generic_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  ln -s -- "${generic_manifest}" "${generic_selector_path}"

  run_expect_success diagnose_reports_generic_selector_when_arch_specific_absent "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "selector x86_64: absent" "diagnose generic selector arch-specific absence"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "selector generic: symlink -> ${generic_manifest}" "diagnose generic selector present"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime manifest: valid (${generic_manifest})" "diagnose generic selector manifest valid"
}

case_diagnose_validates_generic_regular_file_selector_when_arch_specific_absent() {
  prepare_case_home diagnose-generic-regular-selector
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  write_runtime_manifest "${generic_selector_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  run_expect_success diagnose_validates_generic_regular_file_selector_when_arch_specific_absent "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "selector x86_64: absent" "diagnose regular generic selector arch-specific absence"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "selector generic: regular file (${generic_selector_path})" "diagnose regular generic selector file report"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime manifest: valid (${generic_selector_path})" "diagnose regular generic selector manifest valid"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: present (${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so)" "diagnose regular generic selector runtime library"
}

case_diagnose_reports_magic_only_runtime_library_for_generic_regular_selector() {
  prepare_case_home diagnose-generic-regular-magic-only
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  invalid_library_path=${WORK_DIR}/magic-only-runtime.so
  write_runtime_manifest "${generic_selector_path}" "${invalid_library_path}"
  write_magic_only_fake_elf_file "${invalid_library_path}"
  assert_readelf_rejected "${invalid_library_path}" "diagnose magic-only runtime library fixture"

  run_expect_success diagnose_reports_magic_only_runtime_library_for_generic_regular_selector "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "selector generic: regular file (${generic_selector_path})" "diagnose magic-only generic selector file report"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime manifest: valid (${generic_selector_path})" "diagnose magic-only generic selector manifest valid"
  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: invalid ELF structure; readelf diagnostics: readelf: Error:" "diagnose magic-only runtime library report"
}

case_diagnose_reports_elf32_runtime_library_for_generic_regular_selector() {
  prepare_case_home diagnose-generic-regular-elf32
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  invalid_library_path=${WORK_DIR}/elf32-runtime.so
  write_runtime_manifest "${generic_selector_path}" "${invalid_library_path}"
  write_elf32_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Class:                             ELF32" "diagnose elf32 runtime library fixture"

  run_expect_success diagnose_reports_elf32_runtime_library_for_generic_regular_selector "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: invalid ELF structure; readelf diagnostics: readelf: Warning:" "diagnose elf32 runtime library report"
}

case_diagnose_reports_wrong_machine_runtime_library_for_generic_regular_selector() {
  prepare_case_home diagnose-generic-regular-wrong-machine
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  invalid_library_path=${WORK_DIR}/wrong-machine-runtime.so
  write_runtime_manifest "${generic_selector_path}" "${invalid_library_path}"
  write_wrong_machine_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Machine:                           Intel 80386" "diagnose wrong-machine runtime library fixture"

  run_expect_success diagnose_reports_wrong_machine_runtime_library_for_generic_regular_selector "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: invalid ELF machine; expected x86-64 shared object (${invalid_library_path})" "diagnose wrong-machine runtime library report"
}

case_diagnose_reports_non_et_dyn_runtime_library_for_generic_regular_selector() {
  prepare_case_home diagnose-generic-regular-non-et-dyn
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  invalid_library_path=${WORK_DIR}/exec-runtime.so
  write_runtime_manifest "${generic_selector_path}" "${invalid_library_path}"
  write_non_et_dyn_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Type:                              EXEC" "diagnose non-et-dyn runtime library fixture"

  run_expect_success diagnose_reports_non_et_dyn_runtime_library_for_generic_regular_selector "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: invalid ELF type; expected ET_DYN shared object (${invalid_library_path})" "diagnose non-et-dyn runtime library report"
}

case_diagnose_reports_truncated_runtime_library_for_generic_regular_selector() {
  prepare_case_home diagnose-generic-regular-truncated
  prepare_fake_steam_install

  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  invalid_library_path=${WORK_DIR}/truncated-runtime.so
  write_runtime_manifest "${generic_selector_path}" "${invalid_library_path}"
  write_truncated_variant_file "${invalid_library_path}"
  assert_readelf_full_status_and_contains "${invalid_library_path}" 0 "Error:" "diagnose truncated runtime library fixture"

  run_expect_success diagnose_reports_truncated_runtime_library_for_generic_regular_selector "${DIAGNOSE_CMD[@]}"

  assert_contains "${RUN_STDOUT}${RUN_STDERR}" "runtime library: invalid ELF structure; readelf diagnostics: readelf: Error:" "diagnose truncated runtime library report"
}

case_runtime_env_child_only() {
  prepare_case_home runtime-env-child-only
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  probe_path=${PROBE_DIR}/probe.sh
  capture_path=${TMP_ROOT}/runtime-env-child-only/capture.txt
  make_env_probe "${probe_path}" "${capture_path}"
  probe_cmd=(bash "${probe_path}")

  unset XR_RUNTIME_JSON
  run_expect_success runtime_env_child_only "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- "${probe_cmd[@]}" "${capture_path}"

  assert_file_exists "${capture_path}"
  runtime_json=$(<"${capture_path}")
  assert_eq "${manifest_path}" "${runtime_json}" "child XR_RUNTIME_JSON"
  assert_not_set "${XR_RUNTIME_JSON-}" "parent XR_RUNTIME_JSON"
}

case_runtime_env_rejects_malformed_manifest() {
  prepare_case_home runtime-env-malformed-manifest

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_malformed_manifest "${manifest_path}"

  run_expect_failure runtime_env_rejects_malformed_manifest "malformed" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_missing_runtime_library() {
  prepare_case_home runtime-env-missing-library

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  missing_library_path=${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/missing-runtime.so
  write_runtime_manifest "${manifest_path}" "${missing_library_path}"

  run_expect_failure runtime_env_rejects_missing_runtime_library "shared library" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_magic_only_runtime_library() {
  prepare_case_home runtime-env-magic-only-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/magic-only-runtime.so
  write_magic_only_fake_elf_file "${invalid_library_path}"
  assert_readelf_rejected "${invalid_library_path}" "runtime-env magic-only runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure runtime_env_rejects_magic_only_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Error:" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_elf32_runtime_library() {
  prepare_case_home runtime-env-elf32-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/elf32-runtime.so
  write_elf32_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Class:                             ELF32" "runtime-env elf32 runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure runtime_env_rejects_elf32_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Warning:" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_wrong_machine_runtime_library() {
  prepare_case_home runtime-env-wrong-machine-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/wrong-machine-runtime.so
  write_wrong_machine_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Machine:                           Intel 80386" "runtime-env wrong-machine runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure runtime_env_rejects_wrong_machine_runtime_library "invalid ELF machine" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_non_et_dyn_runtime_library() {
  prepare_case_home runtime-env-non-et-dyn-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/exec-runtime.so
  write_non_et_dyn_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Type:                              EXEC" "runtime-env non-et-dyn runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure runtime_env_rejects_non_et_dyn_runtime_library "invalid ELF type" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_truncated_runtime_library() {
  prepare_case_home runtime-env-truncated-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/truncated-runtime.so
  write_truncated_variant_file "${invalid_library_path}"
  assert_readelf_full_status_and_contains "${invalid_library_path}" 0 "Error:" "runtime-env truncated runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure runtime_env_rejects_truncated_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Error:" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_missing_file_format_version() {
  prepare_case_home runtime-env-missing-version
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  mkdir -p -- "$(dirname -- "${manifest_path}")"
  cat >"${manifest_path}" <<EOF
{
  "runtime": {
    "library_path": "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"
  }
}
EOF

  run_expect_failure runtime_env_rejects_missing_file_format_version "file_format_version" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_runtime_env_rejects_wrong_file_format_version() {
  prepare_case_home runtime-env-wrong-version
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_manifest_with_version "${manifest_path}" "2.0.0" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  run_expect_failure runtime_env_rejects_wrong_file_format_version "file_format_version" "${RUNTIME_ENV_CMD[@]}" --manifest "${manifest_path}" -- /bin/true
}

case_selector_rejects_missing_shared_library() {
  prepare_case_home selector-missing-library

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  run_expect_failure selector_rejects_missing_shared_library "shared library" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_magic_only_runtime_library() {
  prepare_case_home selector-magic-only-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/magic-only-runtime.so
  write_magic_only_fake_elf_file "${invalid_library_path}"
  assert_readelf_rejected "${invalid_library_path}" "selector magic-only runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure selector_rejects_magic_only_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Error:" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_elf32_runtime_library() {
  prepare_case_home selector-elf32-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/elf32-runtime.so
  write_elf32_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Class:                             ELF32" "selector elf32 runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure selector_rejects_elf32_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Warning:" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_wrong_machine_runtime_library() {
  prepare_case_home selector-wrong-machine-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/wrong-machine-runtime.so
  write_wrong_machine_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Machine:                           Intel 80386" "selector wrong-machine runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure selector_rejects_wrong_machine_runtime_library "invalid ELF machine" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_non_et_dyn_runtime_library() {
  prepare_case_home selector-non-et-dyn-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/exec-runtime.so
  write_non_et_dyn_variant_file "${invalid_library_path}"
  assert_readelf_contains "${invalid_library_path}" "Type:                              EXEC" "selector non-et-dyn runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure selector_rejects_non_et_dyn_runtime_library "invalid ELF type" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_truncated_runtime_library() {
  prepare_case_home selector-truncated-library
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  invalid_library_path=${WORK_DIR}/truncated-runtime.so
  write_truncated_variant_file "${invalid_library_path}"
  assert_readelf_full_status_and_contains "${invalid_library_path}" 0 "Error:" "selector truncated runtime library fixture"
  write_runtime_manifest "${manifest_path}" "${invalid_library_path}"

  run_expect_failure selector_rejects_truncated_runtime_library "invalid ELF structure; readelf diagnostics: readelf: Error:" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_malformed_manifest() {
  prepare_case_home selector-malformed-manifest

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_malformed_manifest "${manifest_path}"

  run_expect_failure selector_rejects_malformed_manifest "malformed" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_missing_file_format_version() {
  prepare_case_home selector-missing-version
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  mkdir -p -- "$(dirname -- "${manifest_path}")"
  cat >"${manifest_path}" <<EOF
{
  "runtime": {
    "library_path": "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"
  }
}
EOF

  run_expect_failure selector_rejects_missing_file_format_version "file_format_version" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_rejects_wrong_file_format_version() {
  prepare_case_home selector-wrong-version
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_manifest_with_version "${manifest_path}" "2.0.0" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  run_expect_failure selector_rejects_wrong_file_format_version "file_format_version" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
}

case_selector_refuses_unknown_existing_selector() {
  prepare_case_home selector-unknown-existing
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  unknown_target=${TMP_ROOT}/selector-unknown-existing/unknown.json
  printf '%s\n' '{}' >"${unknown_target}"
  ln -s -- "${unknown_target}" "${selector_path}"

  run_expect_failure selector_refuses_unknown_existing_selector "unknown existing selector" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  assert_symlink_target "${selector_path}" "${unknown_target}"
}

case_selector_updates_atomic_symlink() {
  prepare_case_home selector-atomic-update
  prepare_fake_steam_install

  old_manifest=${MANIFEST_DIR}/old-runtime.json
  new_manifest=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${old_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"
  write_runtime_manifest "${new_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  ln -s -- "${old_manifest}" "${selector_path}"

  run_expect_success selector_updates_atomic_symlink "${SELECT_OPENXR_CMD[@]}" --manifest "${new_manifest}"

  assert_symlink_target "${selector_path}" "${new_manifest}"
}

case_selector_detects_active_runtime_shadowing() {
  prepare_case_home selector-shadowing
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  printf '%s\n' 'shadowed selector file' >"${selector_path}"

  run_expect_failure selector_detects_active_runtime_shadowing "shadowing" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  assert_file_exists "${selector_path}"
}

case_selector_creates_backup_and_restores_previous_selector() {
  prepare_case_home selector-backup-restore
  prepare_fake_steam_install

  old_manifest=${MANIFEST_DIR}/old-runtime.json
  new_manifest=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${old_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"
  write_runtime_manifest "${new_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  backup_path=${selector_path}.steamvr-backup
  ln -s -- "${old_manifest}" "${selector_path}"

  run_expect_success selector_creates_backup_and_restores_previous_selector_select "${SELECT_OPENXR_CMD[@]}" --manifest "${new_manifest}"
  assert_symlink_target "${selector_path}" "${new_manifest}"
  assert_symlink_target "${backup_path}" "${old_manifest}"

  run_expect_success selector_creates_backup_and_restores_previous_selector_restore "${SELECT_OPENXR_CMD[@]}" --restore
  assert_symlink_target "${selector_path}" "${old_manifest}"
  assert_file_not_exists "${backup_path}"
}

case_selector_force_preserves_regular_file_and_restores_exact_contents() {
  prepare_case_home selector-force-restore
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  backup_path=${selector_path}.steamvr-backup
  original_contents='{"file_format_version":"1.0.0","runtime":{"library_path":"/tmp/original-runtime.so"}}'
  printf '%s\n' "${original_contents}" >"${selector_path}"

  run_expect_failure selector_force_preserves_regular_file_and_restores_exact_contents_refuses_regular_file "unknown existing selector" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  assert_file_contents "${selector_path}" "${original_contents}" "selector regular file must stay untouched on default refusal"
  assert_file_not_exists "${backup_path}"

  run_expect_success selector_force_preserves_regular_file_and_restores_exact_contents_force "${SELECT_OPENXR_CMD[@]}" --force --manifest "${manifest_path}"
  assert_symlink_target "${selector_path}" "${manifest_path}"
  assert_file_contents "${backup_path}" "${original_contents}" "force backup must preserve exact regular file contents"

  run_expect_success selector_force_preserves_regular_file_and_restores_exact_contents_restore "${SELECT_OPENXR_CMD[@]}" --restore
  assert_file_contents "${selector_path}" "${original_contents}" "restore must bring back exact regular file contents"
  assert_file_not_exists "${backup_path}"
}

case_selector_refuses_when_backup_already_exists() {
  prepare_case_home selector-backup-exists
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  backup_path=${selector_path}.steamvr-backup
  ln -s -- "${manifest_path}" "${selector_path}"
  ln -s -- "${MANIFEST_DIR}/stale-backup.json" "${backup_path}"

  run_expect_failure selector_refuses_when_backup_already_exists "backup already exists" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  assert_symlink_target "${selector_path}" "${manifest_path}"
  assert_symlink_target "${backup_path}" "${MANIFEST_DIR}/stale-backup.json"
}

case_selector_generic_only_select_and_restore_reveals_generic_fallback() {
  prepare_case_home selector-generic-only-restore
  prepare_fake_steam_install

  generic_manifest=${MANIFEST_DIR}/generic-runtime.json
  new_manifest=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${generic_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"
  write_runtime_manifest "${new_manifest}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  backup_path=${selector_path}.steamvr-backup
  absent_marker_path=${selector_path}.steamvr-absent
  ln -s -- "${generic_manifest}" "${generic_selector_path}"

  run_expect_success selector_generic_only_select_and_restore_reveals_generic_fallback_select "${SELECT_OPENXR_CMD[@]}" --manifest "${new_manifest}"
  assert_symlink_target "${selector_path}" "${new_manifest}"
  assert_symlink_target "${generic_selector_path}" "${generic_manifest}"
  assert_file_exists "${absent_marker_path}"
  assert_file_not_exists "${backup_path}"

  run_expect_success selector_generic_only_select_and_restore_reveals_generic_fallback_restore "${SELECT_OPENXR_CMD[@]}" --restore
  assert_file_not_exists "${selector_path}"
  assert_symlink_target "${generic_selector_path}" "${generic_manifest}"
  assert_file_not_exists "${backup_path}"
  assert_file_not_exists "${absent_marker_path}"
}

case_selector_no_selector_select_and_restore_returns_to_absent_state() {
  prepare_case_home selector-no-selector-restore
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  generic_selector_path=${OPENXR_DIR}/active_runtime.json
  backup_path=${selector_path}.steamvr-backup
  absent_marker_path=${selector_path}.steamvr-absent

  run_expect_success selector_no_selector_select_and_restore_returns_to_absent_state_select "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  assert_symlink_target "${selector_path}" "${manifest_path}"
  assert_file_exists "${absent_marker_path}"
  assert_file_not_exists "${backup_path}"

  run_expect_success selector_no_selector_select_and_restore_returns_to_absent_state_restore "${SELECT_OPENXR_CMD[@]}" --restore
  assert_file_not_exists "${selector_path}"
  assert_file_not_exists "${generic_selector_path}"
  assert_file_not_exists "${backup_path}"
  assert_file_not_exists "${absent_marker_path}"
}

case_selector_rejects_simultaneous_backup_and_absent_marker() {
  prepare_case_home selector-stale-backup-and-marker
  prepare_fake_steam_install

  manifest_path=${MANIFEST_DIR}/steamvr-runtime.json
  write_runtime_manifest "${manifest_path}" "${STEAM_ROOT}/steamapps/common/SteamVR/bin/linux64/libopenxr_loader.so"

  selector_path=${OPENXR_DIR}/active_runtime.x86_64.json
  backup_path=${selector_path}.steamvr-backup
  absent_marker_path=${selector_path}.steamvr-absent
  ln -s -- "${manifest_path}" "${backup_path}"
  : >"${absent_marker_path}"

  run_expect_failure selector_rejects_simultaneous_backup_and_absent_marker "backup/absent marker conflict" "${SELECT_OPENXR_CMD[@]}" --manifest "${manifest_path}"
  run_expect_failure selector_rejects_simultaneous_backup_and_absent_marker_restore "backup/absent marker conflict" "${SELECT_OPENXR_CMD[@]}" --restore
}

case_alvr_quality_profile_requires_explicit_subcommand() {
  prepare_case_home alvr-quality-explicit

  run_expect_success alvr_quality_profile_help "${ALVR_QUALITY_PROFILE_CMD[@]}" --help
  assert_contains "${RUN_STDOUT}" "Usage: alvr-quality-profile <status|apply>" "ALVR quality profile help"

  run_expect_failure alvr_quality_profile_requires_subcommand "Usage: alvr-quality-profile" "${ALVR_QUALITY_PROFILE_CMD[@]}"
  run_expect_failure alvr_quality_profile_rejects_unknown "unknown command: implicit" "${ALVR_QUALITY_PROFILE_CMD[@]}" implicit
}

case_alvr_quality_profile_status_is_read_only() {
  prepare_case_home alvr-quality-status
  write_alvr_quality_session
  session_path=${XDG_CONFIG_HOME}/alvr/session.json
  before_hash=$(sha256sum -- "${session_path}")

  run_expect_success alvr_quality_profile_status env \
    ALVR_SESSION_PATH="${session_path}" \
    "${ALVR_QUALITY_PROFILE_CMD[@]}" status

  assert_contains "${RUN_STDOUT}" "Status: applied" "ALVR quality profile status"
  after_hash=$(sha256sum -- "${session_path}")
  assert_eq "${before_hash}" "${after_hash}" "ALVR quality status must not mutate session"
}

case_alvr_quality_profile_status_detects_drift() {
  prepare_case_home alvr-quality-drift
  write_alvr_quality_session
  session_path=${XDG_CONFIG_HOME}/alvr/session.json
  replacement_path=${session_path}.replacement
  jq '.session_settings.video.bitrate.mode.ConstantMbps = 30' "${session_path}" >"${replacement_path}"
  mv -- "${replacement_path}" "${session_path}"
  before_hash=$(sha256sum -- "${session_path}")

  run_expect_failure alvr_quality_profile_status_detects_drift "Status: not applied" env \
    ALVR_SESSION_PATH="${session_path}" \
    "${ALVR_QUALITY_PROFILE_CMD[@]}" status

  after_hash=$(sha256sum -- "${session_path}")
  assert_eq "${before_hash}" "${after_hash}" "ALVR quality drift check must not mutate session"
}

case_alvr_quality_profile_apply_posts_exact_profile_without_direct_write() {
  prepare_case_home alvr-quality-apply
  write_alvr_quality_session
  prepare_mock_curl
  session_path=${XDG_CONFIG_HOME}/alvr/session.json
  expected_session=${TMP_ROOT}/expected-alvr-session.json
  replacement_path=${session_path}.replacement
  cp -- "${session_path}" "${expected_session}"
  jq '.session_settings.video.bitrate.mode.ConstantMbps = 30' "${session_path}" >"${replacement_path}"
  mv -- "${replacement_path}" "${session_path}"

  run_expect_success alvr_quality_profile_apply env \
    PATH="${MOCK_CURL_DIR}:${PATH}" \
    ALVR_CURL_BODY="${ALVR_CURL_BODY}" \
    ALVR_CURL_ARGS="${ALVR_CURL_ARGS}" \
    ALVR_CURL_RESULT_SESSION="${expected_session}" \
    ALVR_DASHBOARD_URL=http://127.0.0.1:18082 \
    ALVR_SESSION_PATH="${session_path}" \
    "${ALVR_QUALITY_PROFILE_CMD[@]}" apply

  assert_contains "${RUN_STDOUT}" "applied and verified" "ALVR quality profile apply"
  assert_contains "${RUN_STDOUT}" "Restart SteamVR from the ALVR Dashboard" "ALVR quality profile restart guidance"
  assert_file_exists "${ALVR_CURL_BODY}"
  assert_file_exists "${ALVR_CURL_ARGS}"
  assert_contains "$(<"${ALVR_CURL_ARGS}")" "http://127.0.0.1:18082/api/dashboard-request" "ALVR dashboard request endpoint"

  jq -e '
    .SetValues as $values
    | def value($path): first($values[] | select([.path[].Name] == $path) | .value);
      value(["session_settings", "video", "bitrate", "mode", "variant"]) == "ConstantMbps"
      and value(["session_settings", "video", "bitrate", "mode", "ConstantMbps"]) == 35
      and value(["session_settings", "video", "preferred_codec", "variant"]) == "Hevc"
      and value(["session_settings", "video", "preferred_fps"]) == 72
      and value(["session_settings", "video", "transcoding_view_resolution", "Absolute", "width"]) == 1856
      and value(["session_settings", "video", "emulated_headset_view_resolution", "Absolute", "width"]) == 1856
      and value(["session_settings", "video", "foveated_encoding", "enabled"]) == true
      and value(["session_settings", "video", "foveated_encoding", "content", "center_size_x"]) == 0.6
      and value(["session_settings", "video", "foveated_encoding", "content", "center_size_y"]) == 0.55
      and value(["session_settings", "video", "foveated_encoding", "content", "edge_ratio_x"]) == 2.0
      and value(["session_settings", "video", "foveated_encoding", "content", "edge_ratio_y"]) == 2.5
      and value(["session_settings", "video", "clientside_post_processing", "enabled"]) == false
  ' "${ALVR_CURL_BODY}" >/dev/null || fail "ALVR quality profile apply: unexpected payload"

  cmp -- "${expected_session}" "${session_path}" >/dev/null || fail "ALVR quality profile apply: read-back session does not match API result"
}

case_alvr_quality_profile_apply_is_idempotent() {
  prepare_case_home alvr-quality-idempotent
  write_alvr_quality_session
  session_path=${XDG_CONFIG_HOME}/alvr/session.json
  before_hash=$(sha256sum -- "${session_path}")

  run_expect_success alvr_quality_profile_apply_idempotent env \
    ALVR_DASHBOARD_URL=http://127.0.0.1:1 \
    ALVR_SESSION_PATH="${session_path}" \
    "${ALVR_QUALITY_PROFILE_CMD[@]}" apply

  assert_contains "${RUN_STDOUT}" "already applied; no API request sent" "ALVR quality idempotent apply"
  after_hash=$(sha256sum -- "${session_path}")
  assert_eq "${before_hash}" "${after_hash}" "ALVR quality idempotent apply must not mutate session"
}

run_case() {
  name=$1
  printf '== %s ==\n' "${name}"
  "case_${name}"
}

main() {
  setup_root
  ensure_jq
  ensure_readelf

  run_case diagnose_missing_steam
  run_case diagnose_read_only_steam
  run_case diagnose_reads_steamxr_manifest_and_resolves_runtime_library
  run_case diagnose_reports_generic_selector_when_arch_specific_absent
  run_case diagnose_validates_generic_regular_file_selector_when_arch_specific_absent
  run_case diagnose_reports_magic_only_runtime_library_for_generic_regular_selector
  run_case diagnose_reports_elf32_runtime_library_for_generic_regular_selector
  run_case diagnose_reports_wrong_machine_runtime_library_for_generic_regular_selector
  run_case diagnose_reports_non_et_dyn_runtime_library_for_generic_regular_selector
  run_case diagnose_reports_truncated_runtime_library_for_generic_regular_selector
  run_case runtime_env_child_only
  run_case runtime_env_rejects_malformed_manifest
  run_case runtime_env_rejects_missing_runtime_library
  run_case runtime_env_rejects_magic_only_runtime_library
  run_case runtime_env_rejects_elf32_runtime_library
  run_case runtime_env_rejects_wrong_machine_runtime_library
  run_case runtime_env_rejects_non_et_dyn_runtime_library
  run_case runtime_env_rejects_truncated_runtime_library
  run_case runtime_env_rejects_missing_file_format_version
  run_case runtime_env_rejects_wrong_file_format_version
  run_case selector_rejects_missing_shared_library
  run_case selector_rejects_magic_only_runtime_library
  run_case selector_rejects_elf32_runtime_library
  run_case selector_rejects_wrong_machine_runtime_library
  run_case selector_rejects_non_et_dyn_runtime_library
  run_case selector_rejects_truncated_runtime_library
  run_case selector_rejects_malformed_manifest
  run_case selector_rejects_missing_file_format_version
  run_case selector_rejects_wrong_file_format_version
  run_case selector_refuses_unknown_existing_selector
  run_case selector_updates_atomic_symlink
  run_case selector_detects_active_runtime_shadowing
  run_case selector_creates_backup_and_restores_previous_selector
  run_case selector_force_preserves_regular_file_and_restores_exact_contents
  run_case selector_refuses_when_backup_already_exists
  run_case selector_generic_only_select_and_restore_reveals_generic_fallback
  run_case selector_no_selector_select_and_restore_returns_to_absent_state
  run_case selector_rejects_simultaneous_backup_and_absent_marker
  run_case alvr_quality_profile_requires_explicit_subcommand
  run_case alvr_quality_profile_status_is_read_only
  run_case alvr_quality_profile_status_detects_drift
  run_case alvr_quality_profile_apply_posts_exact_profile_without_direct_write
  run_case alvr_quality_profile_apply_is_idempotent

  printf 'steamvr tool contract tests passed\n'
}

main "$@"
