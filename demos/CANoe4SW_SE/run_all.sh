#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

# check if user is root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root / via sudo!"
    exit 1
fi

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# silKitDir=/home/vector/SilKit/SilKit-4.0.50-ubuntu-18.04-x86_64-gcc/
silKitDir=/home/dev/vfs/SILKit/SilKit-5.0.1-ubuntu-22.04-x86_64-gcc
# if "exported_full_path_to_silkit" environment variable is set (in pipeline script), use it. Otherwise, use default value
silKitDir="${exported_full_path_to_silkit:-$silKitDir}"
if [ ! -d "$silKitDir" ]; then
    echo "The var 'silKitDir' needs to be set to actual location of your SIL Kit"
    exit 1
fi

logDir=$scriptDir/logs # define a directory for .out files
mkdir -p $logDir # if it does not exist, create it

veIPCDir="$scriptDir/../veIPC"
imageDir="$veIPCDir/qos227_iopkt_21082025_qemu_image"
zipFile="$veIPCDir/qos227_vtt_example_qemu.tar.gz"

# create a timestamp for log files
timestamp=$(date +"%Y%m%d_%H%M%S")
DELAY_SECONDS=5

get_qemu_pid() {
  pgrep -f 'qemu-system-x86_64 .* -drive file=output/disk-qemu.vmdk,if=ide,id=drv0 .* -kernel output/ifs.bin' | head -n1 || true
}

cleanup_remote_app() {
    echo "[info] Requesting remote app kill"
    "$veIPCDir/handle_remote_app.sh" kill >/dev/null 2>&1 || true
}

cleanup_adapter() {
  if [ -n "$ADAPTER_PID" ]; then
    echo "[info] Attempting adapter shutdown (PID $ADAPTER_PID)"
    if kill -0 "$ADAPTER_PID" 2>/dev/null; then
      kill -TERM "$ADAPTER_PID" 2>/dev/null || true
    else
      echo "[info] Adapter already exited"
    fi
  fi
}

cleanup_background_jobs() {
  for jp in $(jobs -p 2>/dev/null); do
    [ -n "$ADAPTER_PID" ] && [ "$jp" = "$ADAPTER_PID" ] && continue
    echo "[info] Killing background job $jp"
    kill -TERM "$jp" 2>/dev/null || true
  done
}

cleanup_qemu() {
  [ -z "$QEMU_PID" ] && QEMU_PID="$(get_qemu_pid)"
  [ -z "$QEMU_PID" ] && return 0
  if kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "[info] Force killing QEMU PID $QEMU_PID"
    kill -KILL "$QEMU_PID" 2>/dev/null || true
  fi
}

cleanup() {
  echo "[info] Ctrl+C received. Cleaning up."
  set +e
  cleanup_adapter
  cleanup_remote_app
  cleanup_background_jobs
  cleanup_qemu
  echo "[info] Cleanup complete."
  exit 0
}

trap cleanup INT TERM

ACTION="${1:-start}"          # 'start' (default) or 'kill'

HANDLE_REMOTE_APP_SCRIPT="$veIPCDir/handle_remote_app.sh"

# Check if $imageDir folder exists, and unzip if necessary
if [ ! -d "$imageDir" ]; then
  echo "[info] $imageDir folder not found. Attempting to unzip $zipFile..."
  if [ -f "$zipFile" ]; then
    tar -xf "$zipFile" -C "$veIPCDir" --same-owner --preserve-permissions
    echo "[info] $imageDir folder created successfully."
  else
    echo "[error] $zipFile file not found"
    exit 1
  fi
else
  echo "[info] $imageDir folder already exists."
fi

# start SIL Kit registry
echo "[info] Starting sil-kit-registry"
$silKitDir/SilKit/bin/sil-kit-registry --listen-uri 'silkit://0.0.0.0:8501' &> $logDir/sil-kit-registry_${timestamp}.out &
sleep 1 # wait 1 second for the creation/existense of the .out file
timeout 30s grep -q 'Press Ctrl-C to terminate...' <(tail -f $logDir/sil-kit-registry_${timestamp}.out -n +1) || { echo "[error] Timeout reached while waiting for sil-kit-registry to start"; exit 1; }

echo "[info] Preparing host to run QEMU image"
$veIPCDir/qemu_setup.sh
echo "[info] Starting QEMU image (background)"
cd "$imageDir"
pwd
ls
./run_qemu_image.sh
echo "[info] QEMU started; active PID: $(get_qemu_pid)"
echo "[info] Sleeping ${DELAY_SECONDS}s to let SSH service start..."
sleep "$DELAY_SECONDS"

echo "[info] Invoking remote-start (start_little_endian)"
"$HANDLE_REMOTE_APP_SCRIPT" start_little_endian || { echo "[error] remote-start failed"; exit 1; }

# Start adapter
echo "[info] Starting SIL Kit adapter (little_endian)"
"$scriptDir/../../bin/sil-kit-adapter-veipc" 192.168.1.3:6666,toSocket,fromSocket \
  > "$scriptDir/logs/sil-kit-adapter-veipc-little_endian-$(date +%Y%m%d_%H%M%S).out" 2>&1 &
ADAPTER_PID=$!
echo "[info] Adapter PID: $ADAPTER_PID"

#### GENERATE DATA & TEST LITTLE_ENDIAN #### 

echo "[info] Stopping remote adapter to restart it with big_endian"
cleanup_adapter
echo "[info] Stopping remote app to restart it with start_big_endian"
"$HANDLE_REMOTE_APP_SCRIPT" kill 

echo "[info] Invoking remote-start (start_big_endian)"
"$HANDLE_REMOTE_APP_SCRIPT" start_big_endian || { echo "[error] remote-start failed"; exit 1; }

echo "[info] Starting SIL Kit adapter (big_endian)"
"$scriptDir/../../bin/sil-kit-adapter-veipc" 192.168.1.3:6666,toSocket,fromSocket --endianness big_endian \
  > "$scriptDir/logs/sil-kit-adapter-veipc-big_endian-$(date +%Y%m%d_%H%M%S).out" 2>&1 &
ADAPTER_PID=$!
echo "[info] Adapter PID: $ADAPTER_PID"

#### GENERATE DATA & TEST BIG_ENDIAN #### 

echo "[info] QEMU and remote application running. Use Ctrl+C to terminate run_all.sh."
while true; do sleep 2; done