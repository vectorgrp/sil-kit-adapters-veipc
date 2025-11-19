#!/bin/bash
script_root=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#run test unit
echo "[info] Running tests"
$canoe4sw_se_install_dir/canoe4sw-se $script_root/Default.venvironment -d "$script_root/working-dir" --verbosity-level "2" --test-unit "$script_root/testEchoServer.vtestunit"  --show-progress "tree-element"
exit $?