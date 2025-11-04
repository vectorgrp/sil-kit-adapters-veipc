# Vector SIL Kit Adapter veIPC
This collection of software is provided to illustrate how the [Vector SIL Kit](https://github.com/vectorgrp/sil-kit/) can bridge any socket and transmit veIPC (Vector Module for Interprocessor Communication) messages between it and a pair of SIL Kit Topics.

This repository contains instructions to set up development environment and build the adapter, as well as a simple demo to showcase the functionality.

# Getting Started
Those instructions assume you use WSL (Ubuntu) or a Linux OS for building and running the adapter (nevertheless it is also possible to do this directly on a Windows system), and use ``bash`` as your interactive shell.

## a) Getting Started with pre-built Adapter
Download a preview or release of the adapter directly from [Vector SIL Kit Adapter veIPC Releases](https://github.com/vectorgrp/sil-kit-adapters-veipc/releases).

If not already existent on your system you should also download a SIL Kit Release directly from [Vector SIL Kit Releases](https://github.com/vectorgrp/sil-kit/releases). You will need this for being able to start a sil-kit-registry.

## b) Getting Started with self-built Adapter
This section specifies steps you should do if you have just cloned the repository.

Before any of those topics, please change your current directory to the top-level in the ``sil-kit-adapters-veipc`` repository:

    cd /path/to/sil-kit-adapters-veipc

### Fetch Third Party Software
The first thing that you should do is initializing the submodules to fetch the required third party softwares:

    git submodule update --init --recursive

### Build the Adapter
To build the adapter and demos, you will need a SIL Kit package ``SilKit-x.y.z-$platform`` for your platform. You can download it directly from [Vector SIL Kit Releases](https://github.com/vectorgrp/sil-kit/releases).
The easiest way would be to download it with your web browser, unzip it and place it on your Windows file system, where it also can be accessed by WSL.

The adapter and demos are built using ``cmake``:

    cmake --preset linux-release -DSILKIT_PACKAGE_DIR=/path/to/SilKit-x.y.z-$platform/ 
    cmake --build --preset linux-release --parallel
    

> If you have a self-built or pre-built version of SIL Kit, you can build the adapter against it by setting SILKIT_PACKAGE_DIR to the path, where the bin, include and lib directories are.

> If you have SIL Kit installed on your system, you can build the adapter against it by not providing SILKIT_PACKAGE_DIR to the installation path at all. Hint: Be aware, if you are using WSL2 this may result in issue where your Windows installation of SIL Kit is found. To avoid this specify SILKIT_PACKAGE_DIR.

> If you don't provide a specific path for SILKIT_PACKAGE_DIR and there is no SIL Kit installation on your system, a SIL Kit release package (the default version listed in CMakeLists.txt) will be fetched from github.com and the adapter will be built against it.

> The Adapter can be cross-compiled to be used in QNX environments. In order to acheive that, you can cross-build the adapter for QNX systems using the provided CMake toolchain files inside the common/cmake folder.

The adapter and demo executables will be available in the ``bin`` directory as well as the ``SilKit.dll`` if you are on Windows. Additionally the ``SilKit.lib`` on Windows and the ``libSilKit.so`` on Linux are automatically copied to the ``lib`` directory.

# Run the sil-kit-adapter-veipc
This application allows the user to establish a datagram-based connection with a socket in order to bridge it to the SIL Kit:

All data received from the socket will be sent to the publish topic specified to sil-kit-adapter-veipc.
All data received on the subscribed topic specified to sil-kit-adapter-veipc will be sent to the socket.

Before you start the adapter there always needs to be a sil-kit-registry running already. Start it e.g. like this:

    /path/to/SilKit-x.y.z-$platform/SilKit/bin/sil-kit-registry --listen-uri 'silkit://0.0.0.0:8501'

The application takes the following command line arguments (defaults in curly braces if you omit the switch):
```
   sil-kit-adapter-veipc [<host>:<port>,[<namespace>::]<toAdapter topic name>[~<subscriber's name>]
                                         [,<label key>:<optional label value>
                                         |,<label key>=<mandatory label value>],
                                        [<namespace>::]<fromAdapter topic name>[~<publisher's name>]
                                         [,<label key>:<optional label value>
                                         |,<label key>=<mandatory label value>]]
                         [--name <participant's name{SilKitAdapterVeIpc}>]
                         [--configuration <path to .silkit.yaml or .json configuration file>]
                         [--registry-uri silkit://<host{localhost}>:<port{8501}>]
                         [--log <Trace|Debug|Warn|{Info}|Error|Critical|Off>]
                         [--endianness <big_endian|{little_endian}>]
```
There needs to be at least one ``<host>:<port>,<toAdapterTopic>,<fromAdapterTopic>`` argument, and each socket needs to be unique.

SIL Kit-specific CLI arguments will be overwritten by the config file passed by ``--configuration``.

> **Example:**
Here is an example that runs the veIPC Adapter and demonstrates the basic form of parameters that the adapter takes into account: 
> 
>     sil-kit-adapter-veipc localhost:81,toVeIpc,fromVeIpc --name SilKitAdapterVeIpc_test 
>
> In this example, the adapter has `SilKitAdapterVeIpc_test` as participant name, and uses the default values for SIL Kit URI connection (`silkit://localhost:8501`). `localhost` and port `81` are used to establish a socket connection to a source of bidirectional data. When the socket is emitting data, the adapter will send them to the topic named `fromVeIpc`, and when data arrive on the `toVeIpc` topic, they are sent through the socket.


## Datagram framing and endianness 

The following scheme guives an overview of the data flow between the peer application's socket, the SIL Kit Adapter veIPC and CANoe.

                        +------------------+--------------------------+
                        | Payload Length   |     Payload Data         |
                        |     (2 bytes)    |    (variable size)       |
                        +------------------+--------------------------+
                                              \
                                               \  
            +---------------------+--------+    )   +---------------+       
            |  Peer Application   | Socket |< ---- >|   SKA veIPC   |       
            +---------------------+--------+        +---------------+       
                                                            ^
                                                            | _                  +--------------------+
                                                            |   \ _____________  |    Payload Data    |
                                                            v                    |   (variable size)  |
                                                    +-----------+                +--------------------+
                                                    |   CANoe   |             
                                                    +-----------+ 

Flow:
- Peer application sends framed datagrams: 2‑byte length header + payload.
- Adapter decodes length (respecting `--endianness`), publishes payload to SIL Kit topic.
- Incoming SIL Kit data is re-framed into (length header + payload) and written back to the socket.
- CANoe (or any SIL Kit participant) consumes/produces payloads without needing to handle the length header.

The adapter treats each datagram as a framed payload with a size field at the beginning. The `--endianness` argument controls how multi-byte numeric fields are interpreted when converting between the raw socket data and SIL Kit payloads.

**Important:** Choose `--endianness` to match what the peer application (the process on the other end of the socket) expects for the length header. If they differ, the peer will misinterpret frame sizes and behavior becomes undefined (truncated, merged, or discarded PDUs).