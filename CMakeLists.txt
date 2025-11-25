# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT
	
cmake_minimum_required(VERSION 3.13)
project(VectorSilKitAdapterVeIpc)

set(SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin")
set(SILKIT_ADAPTER_VEIPC_LIBRARY_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib")

set(SILKIT_ADAPTER_VEIPC_VERSION "0.9.0")

include(common/cmake/RepoTargets.cmake)

add_subdirectory(adapter)
add_subdirectory(demos)

include(common/cmake/InstallFunctions.cmake)

fix_windows_install_folder("SIL Kit Adapter veIPC" ${SILKIT_ADAPTER_VEIPC_VERSION})

install_adapter_source(
    ${CMAKE_CURRENT_SOURCE_DIR}/adapter
    ${CMAKE_CURRENT_SOURCE_DIR}/demos
)
install_git_source(${CMAKE_CURRENT_SOURCE_DIR}/common)
install_root_source_files()

install_silkit_lib(
    ${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}
    ${SILKIT_ADAPTER_VEIPC_LIBRARY_DIRECTORY}
)

install_adapter(sil-kit-adapter-veipc)
install_demo(sil-kit-demo-veipc-echo-server)
install_demo(sil-kit-demo-veipc-auto-sender)

include(common/cmake/Packaging.cmake)

install_scripts_to(demos/CANoe4SW_SE
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/run.sh
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/createEnvironment.sh
)

install_scripts_to(demos/CANoe4SW_SE/internal
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/internal/run_all.sh
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/internal/handle_remote_app.sh
)

declare_package(
  "SilKit-Adapter-veIPC"
  "binary release of SIL Kit Adapter veIPC"
)
