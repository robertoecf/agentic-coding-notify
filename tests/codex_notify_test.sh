#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/adapters/codex/notify.sh"
INSTALLER_PATH="$ROOT_DIR/adapters/codex/install.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [ "$actual" != "$expected" ]; then
    fail "$label: expected '$expected', got '$actual'"
  fi
}

run_case() {
  local payload="$1"
  shift
  env NOTIFY_TEST_MODE=1 "$@" "$SCRIPT_PATH" "$payload"
}

printf 'Running Codex notify adapter tests...\n'

if [ ! -x "$SCRIPT_PATH" ]; then
  fail "missing executable Codex adapter at $SCRIPT_PATH"
fi

if [ ! -x "$INSTALLER_PATH" ]; then
  fail "missing executable Codex installer at $INSTALLER_PATH"
fi

review_output="$(
  run_case \
    '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman","last-assistant-message":"READY_FOR_REVIEW: painel pronto","title":"Codex"}' \
    TERM_PROGRAM=Ghostty
)"

review_subtitle="$(printf '%s' "$review_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["subtitle"])')"
review_message="$(printf '%s' "$review_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["message"])')"
review_label="$(printf '%s' "$review_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"
review_voice="$(printf '%s' "$review_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["voice_label"])')"

assert_eq "$review_subtitle" "Pronto para revisao" "review subtitle"
assert_eq "$review_message" "painel pronto" "review message"
assert_eq "$review_label" "Ghostty" "review label"
assert_eq "$review_voice" "Codex Ghostty" "review voice"

input_output="$(
  run_case \
    '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman","last-assistant-message":"INPUT_NEEDED: informar firm_id","title":"Codex"}' \
    TERM_PROGRAM=Apple_Terminal
)"

input_subtitle="$(printf '%s' "$input_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["subtitle"])')"
input_message="$(printf '%s' "$input_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["message"])')"
input_label="$(printf '%s' "$input_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"

assert_eq "$input_subtitle" "Input necessario" "input subtitle"
assert_eq "$input_message" "informar firm_id" "input message"
assert_eq "$input_label" "Terminal.app" "input label"

stdin_output="$(
  env NOTIFY_TEST_MODE=1 TERM_PROGRAM=vscode "$SCRIPT_PATH" \
    <<< '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman","last-assistant-message":"AUTH_NEEDED: liberar acesso","title":"Codex"}'
)"

stdin_subtitle="$(printf '%s' "$stdin_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["subtitle"])')"
stdin_message="$(printf '%s' "$stdin_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["message"])')"
stdin_label="$(printf '%s' "$stdin_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"

assert_eq "$stdin_subtitle" "Autorizacao necessaria" "stdin subtitle"
assert_eq "$stdin_message" "liberar acesso" "stdin message"
assert_eq "$stdin_label" "VS Code" "stdin label"

fallback_output="$(
  env -u TERM_PROGRAM NOTIFY_TEST_MODE=1 "$SCRIPT_PATH" \
    '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman-os","last-assistant-message":"deploy concluido","title":"Codex"}'
)"

fallback_subtitle="$(printf '%s' "$fallback_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["subtitle"])')"
fallback_message="$(printf '%s' "$fallback_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["message"])')"
fallback_label="$(printf '%s' "$fallback_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"
fallback_voice="$(printf '%s' "$fallback_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["voice_label"])')"

assert_eq "$fallback_subtitle" "Turno concluido" "fallback subtitle"
assert_eq "$fallback_message" "deploy concluido" "fallback message"
assert_eq "$fallback_label" "wealthuman-os" "fallback label"
assert_eq "$fallback_voice" "Codex wealthuman-os" "fallback voice"

app_output="$(
  env -u TERM_PROGRAM \
    NOTIFY_TEST_MODE=1 \
    CODEX_NOTIFY_PARENT_PROCESS_TREE="/Applications/Codex.app/Contents/MacOS/Codex" \
    "$SCRIPT_PATH" \
    '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman-os","last-assistant-message":"READY_FOR_REVIEW: app pronto","title":"Codex"}'
)"

app_label="$(printf '%s' "$app_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"
app_voice="$(printf '%s' "$app_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["voice_label"])')"

assert_eq "$app_label" "Codex App" "app label"
assert_eq "$app_voice" "Codex App" "app voice"

terminal_output="$(
  env -u TERM_PROGRAM NOTIFY_TEST_MODE=1 "$SCRIPT_PATH" \
    '{"type":"agent-turn-complete","cwd":"/tmp/wealthuman-os","last-assistant-message":"READY_FOR_REVIEW: terminal pronto","title":"Codex"}'
)"

terminal_label="$(printf '%s' "$terminal_output" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["label"])')"

assert_eq "$terminal_label" "wealthuman-os" "terminal fallback label"

config_output="$("$INSTALLER_PATH" --print-config "/tmp/codex-notify.sh")"
expected_line='notify = ["/tmp/codex-notify.sh"]'

if ! printf '%s\n' "$config_output" | grep -Fqx "$expected_line"; then
  fail "installer config output missing notify line"
fi

printf 'PASS: Codex notify adapter tests\n'
