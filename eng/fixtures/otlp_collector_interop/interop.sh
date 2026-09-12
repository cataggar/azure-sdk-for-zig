#!/usr/bin/env bash
set -euo pipefail
umask 077

FIXTURE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
usage() {
  echo "Usage: bash $0 /absolute/path/to/otelcol [--keep-output]" >&2
  echo "Opt-in Linux interop; requires the pinned official otelcol archive, Zig 0.16.0 and /proc." >&2
}
[[ $# -ge 1 && $# -le 2 ]] || { usage; exit 2; }
COLLECTOR="$1"
KEEP=false
if [[ $# == 2 ]]; then
  [[ "$2" == --keep-output ]] || { usage; exit 2; }
  KEEP=true
fi
[[ "$COLLECTOR" == /* && -x "$COLLECTOR" ]] || {
  echo "Missing optional Collector executable: $COLLECTOR (see README.md for pinned setup)." >&2
  exit 2
}
[[ "$(uname -s)" == Linux && -r /proc/self/net/tcp ]] || {
  echo "This opt-in runner requires Linux /proc for child-owned listener discovery." >&2
  exit 2
}
for tool in zig timeout readlink awk; do
  command -v "$tool" >/dev/null || { echo "Missing optional interop tool: $tool" >&2; exit 2; }
done
[[ "$(timeout --kill-after=1s 5s "$COLLECTOR" --version)" == "otelcol version 0.120.1" ]] || {
  echo "Expected official v0.120.0 release archive (binary reports 0.120.1); see README.md." >&2
  exit 2
}

cd "$FIXTURE"
zig build interop-tools --summary all
[[ ! -L .interop ]] || { echo "Refusing symlink .interop" >&2; exit 1; }
mkdir -p .interop
WORK="$FIXTURE/.interop/run-$$-$RANDOM"
mkdir "$WORK"
PID=""
stop_collector() {
  local status=0 i
  [[ -n "$PID" ]] || return 0
  if kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null || true
    for ((i = 0; i < 50; i++)); do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$PID" 2>/dev/null; then
      kill -KILL "$PID" 2>/dev/null || true
      status=124
    fi
  fi
  wait "$PID" 2>/dev/null || status=$?
  PID=""
  return "$status"
}
cleanup() {
  local status=$?
  stop_collector || true
  if [[ $status != 0 && -f "$WORK/collector.log" ]]; then
    tail -c 8192 "$WORK/collector.log" >&2
  fi
  if [[ $status != 0 && -f "$WORK/response.json" ]]; then
    tail -c 4096 "$WORK/response.json" >&2
  fi
  if $KEEP; then
    echo "Local mock-only evidence: $WORK" >&2
  else
    rm -f -- "$WORK/request.json" "$WORK/wire_traceparent.txt" \
      "$WORK/response.json" "$WORK/accepted.jsonl" "$WORK/collector.log"
    rmdir -- "$WORK"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

cd "$WORK"
"$FIXTURE/zig-out/bin/otlp-collector-fixture" capture
# Bound each output file even if the optional process misbehaves. The child
# stays attached; only its exact PID is signalled and reaped.
(
  ulimit -f 2048
  exec "$COLLECTOR" --config="$FIXTURE/collector.yaml"
) >collector.log 2>&1 &
PID=$!

owned_port() {
  local fd link inode address found=""
  kill -0 "$PID" 2>/dev/null || return 1
  # Port zero is acquired by the Collector itself, without a probe/rebind race.
  # Match a listening socket inode held by this exact child, never another
  # service sharing the network namespace. No traffic is sent on failure.
  for fd in /proc/"$PID"/fd/*; do
    link="$(readlink "$fd" 2>/dev/null)" || continue
    [[ "$link" =~ ^socket:\[([0-9]+)\]$ ]] || continue
    inode="${BASH_REMATCH[1]}"
    address="$(awk -v inode="$inode" '$4 == "0A" && $10 == inode { print $2 }' "/proc/$PID/net/tcp")"
    [[ -n "$address" ]] || continue
    [[ "$address" =~ ^0100007F:([0-9A-F]{4})$ && -z "$found" ]] || return 1
    found="$((16#${BASH_REMATCH[1]}))"
  done
  [[ -n "$found" && "$found" != 0 ]] || return 1
  printf '%s\n' "$found"
}
PORT=""
for ((attempt = 0; attempt < 100; attempt++)); do
  kill -0 "$PID" 2>/dev/null || { echo "Collector exited before binding." >&2; exit 1; }
  if PORT="$(owned_port)"; then break; fi
  sleep 0.1
done
[[ -n "$PORT" ]] || { echo "No child-owned loopback receiver within 10 seconds." >&2; exit 1; }
[[ "$(owned_port)" == "$PORT" ]] || exit 1
# The separate HTTP tool accepts only a port on fixed loopback, follows no
# redirects, discovers no proxies and bounds input/response sizes.
timeout --kill-after=1s 5s "$FIXTURE/zig-out/bin/collector-http-fixture" probe "$PORT"
[[ "$(owned_port)" == "$PORT" ]] || exit 1
timeout --kill-after=1s 5s "$FIXTURE/zig-out/bin/collector-http-fixture" post "$PORT"
for ((attempt = 0; attempt < 50; attempt++)); do
  kill -0 "$PID" 2>/dev/null || { echo "Collector exited before file export." >&2; exit 1; }
  [[ -s accepted.jsonl ]] && break
  sleep 0.1
done
[[ -s accepted.jsonl ]] || { echo "No Collector file output within 5 seconds." >&2; exit 1; }
stop_collector
"$FIXTURE/zig-out/bin/otlp-collector-fixture" verify \
  request.json wire_traceparent.txt response.json accepted.jsonl
echo "Official otelcol v0.120.0 archive (reports 0.120.1): HTTP 200 on child-owned 127.0.0.1:$PORT; local file export verified."
