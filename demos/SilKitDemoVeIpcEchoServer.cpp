// SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
// SPDX-License-Identifier: MIT

#include <iostream>
#include <iomanip>
#include <vector>
#include <cstring>

#include "common/Parsing.hpp"
#include "common/Cli.hpp"
#include "common/util/WriteUint.hpp"

#include "asio/io_context.hpp"
#include "asio/ip/tcp.hpp"

using namespace adapters;
using namespace adapters::datagram_socket;
using namespace util;

constexpr uint16_t DEFAULT_PORT = 6666;
constexpr const char* DEFAULT_ADDRESS = "0.0.0.0";
constexpr size_t HEADER_SIZE = 2;

uint16_t ExtractMessageSize(const uint8_t* header, Endianness endianness)
{
    if (endianness == Endianness::little_endian)
    {
        return static_cast<uint16_t>(header[0]) | (static_cast<uint16_t>(header[1]) << 8);
    }
    else
    {
        return static_cast<uint16_t>(header[1]) | (static_cast<uint16_t>(header[0]) << 8);
    }
}

void PrintMessage(const std::vector<uint8_t>& echoBuffer, uint16_t messageSize)
{
    // print up to 64 bytes to keep the output clean
    for (size_t i = 0; i < (HEADER_SIZE + messageSize) && i < 64; ++i)
    {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                << static_cast<int>(echoBuffer[i]) << " ";
    }
    if (messageSize > 64)
        std::cout << "...";
    std::cout << '\n' << std::dec;
}

void HandleClient(asio::ip::tcp::socket socket, Endianness endianness)
{
    try
    {
        uint8_t header[HEADER_SIZE];
        std::vector<uint8_t> echoBuffer;

        while (true)
        {
            // read header
            size_t headerBytesRead = asio::read(socket, asio::buffer(header, HEADER_SIZE));
            if (headerBytesRead != HEADER_SIZE)
            {
                std::cout << "[Error] Invalid header size: " << headerBytesRead << " bytes (expected " << HEADER_SIZE << ")\n";
                break;
            }
            
            uint16_t messageSize = ExtractMessageSize(header, endianness);
            if (messageSize == 0)
            {
                std::cout << "[Warn] Received message with size 0" << '\n';
                continue;
            }

            // resize buffer to hold header + data
            echoBuffer.resize(HEADER_SIZE + messageSize);
            
            std::memcpy(echoBuffer.data(), header, HEADER_SIZE);
            
            // read data directly into echo buffer (after header)
            size_t dataBytesRead = asio::read(socket, asio::buffer(echoBuffer.data() + HEADER_SIZE, messageSize));
            
            if (dataBytesRead != messageSize)
            {
                std::cout << "[Error] Data size mismatch! Header indicated " << messageSize 
                          << " bytes, but received " << dataBytesRead << " bytes" << '\n';
                break;
            }

            std::cout << "[Info] Reading " << HEADER_SIZE + messageSize << " bytes: ";
            PrintMessage(echoBuffer, messageSize);

            // echo back
            std::cout << "[Info] Writing " << HEADER_SIZE + messageSize << " bytes: ";
            PrintMessage(echoBuffer, messageSize);

            asio::write(socket, asio::buffer(echoBuffer));
        }
    }
    catch (const std::exception& e)
    {
        std::cout << "[Info] Connection closed: " << e.what() << '\n';
    }
}

void PrintHelp(bool userRequested = false)
{
    // clang-format off
    std::cout << "Usage (defaults in curly braces if you omit the switch):" << std::endl;
    std::cout << "sil-kit-demo-veipc-echo-device [" << endiannessArg << " <big_endian|{little_endian}>]\n";
    std::cout << "\n"
        "Example:\n"
        "sil-kit-demo-veipc-echo-device " << endiannessArg << " little_endian\n";

    if (!userRequested)
        std::cout << "\n"
            "Pass "<<helpArg<<" to get this message.\n";
    // clang-format on
};

int main(int argc, char** argv)
{
    try
    {
        if (findArg(argc, argv, "--help", argv) != nullptr)
        {
            PrintHelp(true);
            return CodeSuccess;
        }

        const std::array<const std::string*, 1> switchesWithArg = {&endiannessArg};
        const std::array<const std::string*, 1> switchesWithoutArg = {&helpArg};
        
        throwInvalidCliIf(thereAreUnknownArguments(argc, argv, switchesWithArg, switchesWithoutArg));

        // parse endianness option
        const std::string endiannessValue = getArgDefault(argc, argv, endiannessArg, "little_endian");
        Endianness endianness = Endianness::little_endian;
        if (endiannessValue == "big_endian")
            endianness = Endianness::big_endian;
        else if (endiannessValue != "little_endian")
        {
            std::cerr << "[Error] Invalid endianness value '" << endiannessValue << "'. Expected 'big_endian' or 'little_endian'." << '\n';
            throw InvalidCli();
        }

        std::cout << "[Info] Using " << endiannessValue << " for header size" << '\n';

        asio::io_context io;
        asio::ip::tcp::acceptor acceptor(io, {asio::ip::address::from_string(DEFAULT_ADDRESS), DEFAULT_PORT});

        std::cout << "[Info] Server listening on " << DEFAULT_ADDRESS << ":" << DEFAULT_PORT << '\n';

        // waits for the client to connect
        asio::ip::tcp::socket socket(io);
        acceptor.accept(socket);
        std::cout << "[Info] Client connected" << '\n';
        
        // handle the client (blocks until client disconnects)
        HandleClient(std::move(socket), endianness);

        std::cout << "[Info] Client disconnected, shutting down" << '\n';
    }
    catch (const std::exception& e)
    {
        std::cerr << "[Error] " << e.what() << '\n';
        return CodeErrorOther;
    }

    return CodeSuccess;
}
