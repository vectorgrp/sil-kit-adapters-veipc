# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT
	
cmake_minimum_required(VERSION 3.13)
project(VectorSilKitAdapterVeIpc)

set(SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin")
set(SILKIT_ADAPTER_VEIPC_LIBRARY_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib")

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)
include(SilKitAdapterVersion)
configure_silkit_adapter_version(${PROJECT_NAME})
add_definitions(-DSILKIT_ADAPTER_VERSION="${PROJECT_VERSION}")

include(common/cmake/RepoTargets.cmake)

add_subdirectory(adapter)
add_subdirectory(demos)

################################################################################
# Distribution of the source code and binaries
################################################################################
# Install sources and binaries
# Copy all files from the source and bin directory to the proper destination
# Leave out git repo related data

include(common/cmake/InstallFunctions.cmake)

fix_windows_install_folder("SIL Kit Adapter veIPC" ${PROJECT_VERSION})

install_adapter_source(
    ${CMAKE_CURRENT_SOURCE_DIR}/adapter
    ${CMAKE_CURRENT_SOURCE_DIR}/demos
    ${CMAKE_CURRENT_SOURCE_DIR}/cmake
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

install_scripts_to(demos/CANoe4SW_SE
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/run.sh
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/run_all.sh
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/createEnvironment.sh
)

install_scripts_to(demos/CANoe4SW_SE/internal
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/internal/run_all.sh
    ${CMAKE_CURRENT_SOURCE_DIR}/demos/CANoe4SW_SE/internal/handle_remote_app.sh
)

###############################################################################
# Packaging
###############################################################################
include(common/cmake/Packaging.cmake)

if(NOT DEFINED PACKAGE_FILENAME_SUFFIX)
    set(PACKAGE_FILENAME_SUFFIX "-${PROJECT_VERSION}")
endif()

declare_package(
  "SilKit-Adapter-veIPC"
  "binary release of SIL Kit Adapter veIPC"
)

set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})