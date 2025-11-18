// SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
// SPDX-License-Identifier: MIT

#include "SilKitAdapterVeIpc.hpp"

#include <thread>
#include <iostream>
#include <chrono>
#include <regex>

#include <asio.hpp>

#include "silkit/util/serdes/Serialization.hpp"
#include "silkit/services/pubsub/all.hpp"

#include "common/Cli.hpp"
#include "common/Parsing.hpp"
#include "common/ParticipantCreation.hpp"
#include "common/SocketToDatagramPubSubAdapter.hpp"

using namespace adapters;
using namespace datagram_socket;
using namespace util;

const std::string adapters::defaultParticipantName = "SilKitAdapterVeIpc";

void print_help(bool userRequested = false)
{
    std::cout << "Usage (defaults in curly braces if you omit the switch):" << std::endl
        << "sil-kit-adapter-veipc" 
        << help::SocketAdapterArgumentHelp("<host>:<port>", "                                     ") << '\n' 
        << "                      [" << participantNameArg << " <participant's name{" << defaultParticipantName << "}>]\n"
        << "                      [" << configurationArg << " <path to .silkit.yaml or .json configuration file>]\n"
        << "                      [" << regUriArg << " silkit://<host{localhost}>:<port{8501}>]\n"
        << "                      [" << logLevelArg << " <Trace|Debug|Warn|{Info}|Error|Critical|Off>]\n"
        << "                      [" << endiannessArg << " <big_endian|{little_endian}>]\n"
        << "\nThe first positional argument is mandatory and must be of the form <host>:<port>,<toAdapterTopic>,<fromAdapterTopic>.\n"
        << "SIL Kit-specific CLI arguments will be overwritten by the config file passed by "
        << configurationArg << ".\n";

    std::cout << "\nExample:\n"
        << "sil-kit-adapter-veipc localhost:6666,toSocket,fromSocket " << endiannessArg << " little_endian\n";

    if (!userRequested)
        std::cout << "\nPass " << helpArg << " to get this message.\n";
};

int main(int argc, char** argv)
{
    if (findArg(argc, argv, helpArg, argv) != NULL)
    {
        print_help(true);
        return CodeSuccess;
    }

    asio::io_context ioContext;
    try
    {
        // Parse endianness switch before creating participant (default little_endian)
        std::string endiannessStr = getArgDefault(argc, argv, endiannessArg, "little_endian");
        Endianness endianness = Endianness::little_endian;
        if (endiannessStr == "big_endian")
            endianness = Endianness::big_endian;
        else if (endiannessStr != "little_endian")
        {
            std::cerr << "Invalid endianness value '" << endiannessStr << "'. Expected 'big_endian' or 'little_endian'." << std::endl;
            throw InvalidCli();
        }

        const std::array<const std::string*,5> switchesWithArg = { &endiannessArg, &regUriArg, &logLevelArg, &participantNameArg, &configurationArg };
        const std::array<const std::string*,1> switchesWithoutArg = { &helpArg };

        // Collect positional socket specifications
        auto socketSpecs = adapters::CollectPositionalSocketArgs(argc, argv, switchesWithArg, switchesWithoutArg);

        // Create SIL Kit participant and services
        SilKit::Services::Logging::ILogger* logger;
        SilKit::Services::Orchestration::ILifecycleService* lifecycleService;
        std::promise<void> runningStatePromise;
        std::string participantName = defaultParticipantName;
        static constexpr uint8_t headerSize = 2; // default typical size field length

        const auto participant = CreateParticipant(argc, argv, logger, &participantName, &lifecycleService, &runningStatePromise);

        // Instantiate socket adapters
        std::vector<std::unique_ptr<SocketToDatagramPubSubAdapter>> transmitters;
        std::set<std::string> alreadyProvidedSockets;
        transmitters.reserve(socketSpecs.size());
        for (auto spec : socketSpecs)
        {
            transmitters.emplace_back(SocketToDatagramPubSubAdapter::parseArgument(
                spec, alreadyProvidedSockets, participantName, ioContext, participant.get(), endianness, headerSize, logger));
        }

        auto finalStateFuture = lifecycleService->StartLifecycle();

        std::thread ioContextThread([&ioContext]() { ioContext.run(); });

        promptForExit();

        Stop(ioContext, ioContextThread, *logger, &runningStatePromise, lifecycleService, &finalStateFuture);
    }
    catch (const SilKit::ConfigurationError& error)
    {
        std::cerr << "Invalid configuration: " << error.what() << std::endl;
        return CodeErrorConfiguration;
    }
    catch (const InvalidCli&)
    {
        print_help();
        std::cerr << std::endl << "Invalid command line arguments." << std::endl;
        return CodeErrorCli;
    }
    catch (const SilKit::SilKitError& error)
    {
        std::cerr << "SIL Kit runtime error: " << error.what() << std::endl;
        return CodeErrorOther;
    }
    catch (const std::exception& error)
    {
        std::cerr << "Something went wrong: " << error.what() << std::endl;
        return CodeErrorOther;
    }

    return CodeSuccess;
}
