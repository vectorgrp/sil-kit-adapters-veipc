#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT
script_root=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

default_canoe4sw_se_install_dir="/opt/vector/canoe-server-edition"
# Check if the executable exists at the default path
if [[ -x "$default_canoe4sw_se_install_dir/canoe4sw-se" ]]; then
  canoe4sw_se_install_dir="$default_canoe4sw_se_install_dir"
else
  # If not found at the default path, search for the executable
  canoe4sw_se_install_dir=$(dirname $(find / -name canoe4sw-se -type f -executable -print -quit 2>/dev/null))
fi

if [[ -n "$canoe4sw_se_install_dir" ]]; then
	echo "[info] canoe4sw-se found at location: $canoe4sw_se_install_dir"
	$canoe4sw_se_install_dir/canoe4sw-se --version
else
  echo "[error] canoe4sw-se executable not found"
  exit 1
fi

export canoe4sw_se_install_dir
$script_root/createEnvironment.sh

#run test unit
echo "[info] Running tests"
$canoe4sw_se_install_dir/canoe4sw-se $script_root/Default.venvironment -d "$script_root/working-dir" --verbosity-level "2" --test-unit "$script_root/testEchoServer.vtestunit"  --show-progress "tree-element"
exit $?
