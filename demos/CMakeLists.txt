# SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
# SPDX-License-Identifier: MIT

add_executable(sil-kit-demo-veipc-echo-device VeIpcEchoDevice.cpp)

target_link_libraries(sil-kit-demo-veipc-echo-device
    PRIVATE
        asio
        sil-kit-adapters-common
)

set_target_properties(sil-kit-demo-veipc-echo-device 
	PROPERTIES
        #ensure SilKit shared libraries can be loaded
        INSTALL_RPATH "$ORIGIN/../lib:$ORIGIN"
        BUILD_RPATH "$ORIGIN"
        RUNTIME_OUTPUT_DIRECTORY $<$<BOOL:ALWAYS>:${SILKIT_ADAPTER_VEIPC_OUTPUT_DIRECTORY}>
)
