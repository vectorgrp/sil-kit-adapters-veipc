# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

add_executable(sil-kit-adapter-veipc
    "SilKitAdapterVeIpc.cpp"
)

target_link_libraries(sil-kit-adapter-veipc
    PRIVATE
        asio
        SilKit::SilKit
        sil-kit-adapters-common
)

set_target_properties(sil-kit-adapter-veipc 
    PROPERTIES
        #ensure SilKit shared libraries can be loaded
        INSTALL_RPATH "$ORIGIN/../lib:$ORIGIN"
        BUILD_RPATH "$ORIGIN"
        RUNTIME_OUTPUT_DIRECTORY $<$<BOOL:ALWAYS>:${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}>
)

include(${CMAKE_CURRENT_LIST_DIR}/../common/cmake/Building.cmake)

copy_sil_kit_to_bin(
  sil-kit-adapter-veipc
  ${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}
  ${SILKIT_ADAPTER_VEIPC_LIBRARY_DIRECTORY}
)
