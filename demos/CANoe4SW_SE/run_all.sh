#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

echo "-----------------------------------------------------------------------"
ps aux | grep sil
echo "-----------------------------------------------------------------------"

# check if user is root
if [[ $EUID -ne 0 ]]; then
  echo "[error] This script must be run as root / via sudo!"
  exit 1
fi

scriptDir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
logdir=$scriptDir/logs
silKitDir=/home/dev/vfs/SILKit/SilKit-5.0.1-ubuntu-22.04-x86_64-gcc/
# if "exported_full_path_to_silkit" environment variable is set (in pipeline script), use it. Otherwise, use default value
silKitDir="${exported_full_path_to_silkit:-$silKitDir}"

# cleanup trap for child processes 
trap 'children=$(pstree -A -p $$); echo "$children" | grep -Eow "[0-9]+" | grep -v $$ | xargs kill &>/dev/null; exit' EXIT SIGHUP;

if [ ! -d "$silKitDir" ]; then
  echo "[error] The var 'silKitDir' needs to be set to actual location of your SIL Kit"
  exit 1
fi

mkdir -p $logdir &>/dev/null

# create a timestamp for log files
timestamp=$(date +"%Y%m%d_%H%M%S")

echo "[info] Starting the SIL Kit registry"
$silKitDir/SilKit/bin/sil-kit-registry --listen-uri 'silkit://0.0.0.0:8501' &> $logdir/sil-kit-registry_$timestamp.out &
sleep 1 # wait 1 second for the creation/existense of the .out file
timeout 30s grep -q 'Press Ctrl-C to terminate...' <(tail -f $logdir/sil-kit-registry_$timestamp.out -n +1) || { echo "[error] Timeout reached while waiting for sil-kit-registry to start"; exit 1; }

# run the tests with little_endian configuration
echo "[info] Starting echo server (little_endian)"
$scriptDir/../../bin/sil-kit-demo-veipc-echo-server --endianness little_endian &> $logdir/sil-kit-demo-veipc-echo-server_little_endian_$timestamp.out &
demo_id=$!

echo "[info] Starting the adapter (little_endian)"
$scriptDir/../../bin/sil-kit-adapter-veipc localhost:6666,toSocket,fromSocket --endianness little_endian \
  &> $logdir/sil-kit-adapter-veipc_little_endian_$timestamp.out &
adapter_id=$!
echo "[info] Starting run.sh test script"
$scriptDir/run.sh
res=$?

exit_status=0

if [[ $res -eq 0 ]]; then
  echo "[info] Tests passed (little_endian)"
else
  echo "[info] Tests failed (little_endian)"
  exit_status=1
fi

# cleanup little_endian processes
echo "[info] Cleaning up little_endian processes"
kill -2 $demo_id $adapter_id &>/dev/null
sleep 1 # wait for processes to terminate

# run the tests with big_endian configuration
echo "[info] Starting echo server (big_endian)"
$scriptDir/../../bin/sil-kit-demo-veipc-echo-server --endianness big_endian &> $logdir/sil-kit-demo-veipc-echo-server_big_endian_$timestamp.out &
demo_id=$!

echo "[info] Starting the adapter (big_endian)"
$scriptDir/../../bin/sil-kit-adapter-veipc localhost:6666,toSocket,fromSocket --endianness big_endian \
  &> $logdir/sil-kit-adapter-veipc_big_endian_$timestamp.out &
adapter_id=$!
echo "[info] Starting run.sh test script"
$scriptDir/run.sh
res=$?

if [[ $res -eq 0 ]]; then
  echo "[info] Tests passed (big_endian)"
else
  echo "[info] Tests failed (big_endian)"
  exit_status=1
fi

# cleanup big_endian processes
echo "[info] Cleaning up big_endian processes"
kill -2 $demo_id $adapter_id &>/dev/null
sleep 1 # wait for processes to terminate and flush logs

# exit run_all.sh with same exit_status
exit $exit_status
