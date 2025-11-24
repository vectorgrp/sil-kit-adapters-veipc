# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

add_executable(sil-kit-demo-veipc-echo-server SilKitDemoVeIpcEchoServer.cpp)

target_link_libraries(sil-kit-demo-veipc-echo-server
    PRIVATE
        asio
        sil-kit-adapters-common
)

set_target_properties(sil-kit-demo-veipc-echo-server 
    PROPERTIES
        #ensure SilKit shared libraries can be loaded
        INSTALL_RPATH "$ORIGIN/../lib:$ORIGIN"
        BUILD_RPATH "$ORIGIN"
        RUNTIME_OUTPUT_DIRECTORY $<$<BOOL:ALWAYS>:${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}>
)

add_executable(sil-kit-demo-veipc-auto-sender SilKitDemoVeIpcAutoSender.cpp)

target_link_libraries(sil-kit-demo-veipc-auto-sender
    PRIVATE
        SilKit::SilKit
        sil-kit-adapters-common
)

set_target_properties(sil-kit-demo-veipc-auto-sender 
    PROPERTIES
        #ensure SilKit shared libraries can be loaded
        INSTALL_RPATH "$ORIGIN/../lib:$ORIGIN"
        BUILD_RPATH "$ORIGIN"
        RUNTIME_OUTPUT_DIRECTORY $<$<BOOL:ALWAYS>:${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}>
)
