#!/bin/bash
# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

script_root=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ -z "$canoe4sw_se_install_dir" ]]; then
  default_canoe4sw_se_install_dir="/opt/vector/canoe-server-edition"
  if [[ -x "$default_canoe4sw_se_install_dir/canoe4sw-se" ]]; then
    canoe4sw_se_install_dir="$default_canoe4sw_se_install_dir"
  fi
fi

if [[ -z "$canoe4sw_se_install_dir" ]]; then
  echo "[error] canoe4sw-se not found."
  exit 1
fi

#display used canoe4sw-se version
$canoe4sw_se_install_dir/canoe4sw-se --version

"$script_root/createEnvironment.sh"
if [[ $? -ne 0 ]]; then
  echo "[error] createEnvironment.sh failed"
  exit 1
fi

#run test unit
echo "[info] Running tests"
$canoe4sw_se_install_dir/canoe4sw-se $script_root/Default.venvironment -d "$script_root/working-dir" --verbosity-level "2" --test-unit "$script_root/testEchoServer.vtestunit"  --show-progress "tree-element"
exit $?