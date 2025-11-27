#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT
set -e

ACTION="${1}"          # 'start_little_endian', 'start_big_endian', or 'kill'

# check if user is root
if [ "$(id -u)" -ne 0 ]; then
  echo "[error] This script must be run as root / via sudo!"
  exit 1
fi

#local related
scriptDir="$(dirname "$(realpath "$0")")"

# ssh related
SSH_USER="root"
SSH_HOST="192.168.1.3"
DELAY_SECONDS=5
export SSHPASS="root"  

# remote related
REMOTE_DIR="/data/home/amsr_externalipc_vtt_example"
REMOTE_BIN="./bin/amsr_externalipc_vtt_example"
REMOTE_INTEGRITY_CHECK="export AMSR_DISABLE_INTEGRITY_CHECK=1"
REMOTE_START_CMD="cd '$REMOTE_DIR'; $REMOTE_INTEGRITY_CHECK; $REMOTE_BIN >/dev/null 2>&1 &"
REMOTE_PROCESS_NAME="nalipc_vtt_example"

remote_exec() {
  # Usage: remote_exec "Message" "command"
  local msg="$1"; shift
  local cmd="$1"
  echo "[remote] $msg"
  sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "$cmd"
}

remote_capture() {
  # Usage: result=$(remote_capture "command")
  local cmd="$1"
  sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_USER@$SSH_HOST" "$cmd"
}

kill_remote_app() {
  # Usage: kill_remote_app <process_name>
  local target_name="$1"
  if [ -z "$target_name" ]; then
    echo "[error] kill_remote_app requires a process name" >&2
    return 1
  fi
  echo "[info] Attempting to kill remote application ($target_name)"
  local pids
  pids=$(remote_capture "pidin | awk -v name='$target_name' '\$3==name {print \$1}' | sort -u" 2>/dev/null || true)
  if [ -z "$pids" ]; then
    echo "[info] No running process found with name $target_name"
    return 0
  fi
  echo "[info] Found PID(s): $pids"
  remote_exec "Killing PID(s) $pids" "for p in $pids; do kill -KILL \$p 2>/dev/null || true; done"
  sleep 1
  local still
  still=$(remote_capture "pidin | awk -v name='$target_name' '\$3==name {print \$1}' | sort -u" 2>/dev/null || true)
  if [ -z "$still" ]; then
    echo "[info] Remote application killed successfully"
  else
    echo "[warn] Remote application still present: $still"
  fi
}

start_remote_app() {
  local endian="$1"

  if [ "$endian" = "little_endian" ]; then
    remote_exec "Updating endianness configuration to: (little_endian)" "sed -ri 's/\"endianness\":[[:space:]]*\"(little|big)_endian\"/\"endianness\": \"little_endian\"/' /data/home/amsr_externalipc_vtt_example/etc/xipc_vtt_config.json"
  else
    remote_exec "Updating endianness configuration to: (big_endian)" "sed -ri 's/\"endianness\":[[:space:]]*\"(little|big)_endian\"/\"endianness\": \"big_endian\"/' /data/home/amsr_externalipc_vtt_example/etc/xipc_vtt_config.json"
  fi
  remote_exec "Launching remote server application ($endian)" "$REMOTE_START_CMD" || echo "[warn] Remote start command returned non-zero"
  echo "[info] Sleeping ${DELAY_SECONDS}s to let remote server application start..."
  sleep "$DELAY_SECONDS"
  echo "[info] Remote server application started ($endian)"
}

case "$ACTION" in
  kill)
    target="${2:-$REMOTE_PROCESS_NAME}"
    kill_remote_app "$target"
    exit 0
    ;;
  start_little_endian)
    start_remote_app "little_endian"
    ;;
  start_big_endian)
    start_remote_app "big_endian"
    ;;
  init_config_file)
    remote_exec "[info] Initialising remote app configuration file" "sed -ri '/\"channel_id\"[[:space:]]*:[[:space:]]*1/,/}/ s/\"address\":[[:space:]]*\"([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\"/\"address\": \"192.168.1.2\"/' /data/home/amsr_externalipc_vtt_example/etc/xipc_vtt_config.json"
    ;;
  *)
    echo "[error] Unknown or missing action: $ACTION"
    echo "Usage: $0 {start_little_endian|start_big_endian|kill [process_name]}"
    exit 1
    ;;
esac