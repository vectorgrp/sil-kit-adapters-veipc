// SPDX-FileCopyrightText: Copyright 2025 Vector Informatik GmbH
// SPDX-License-Identifier: MIT

#include <iostream>
#include <iomanip>
#include <string>
#include <sstream>
#include <vector>
#include <thread>
#include <chrono>
#include <random>

#include "silkit/SilKit.hpp"
#include "silkit/config/all.hpp"
#include "silkit/services/pubsub/all.hpp"
#include "silkit/util/serdes/Serialization.hpp"

#include "common/Parsing.hpp"
#include "common/Cli.hpp"

using namespace adapters;
using namespace util;
using namespace SilKit::Services::PubSub;

static constexpr size_t silkitHeaderSize = 4;

void PrintHelp()
{
    std::cout << "Usage (defaults in curly braces if you omit the switch):" << std::endl;
    std::cout << "sil-kit-demo-veipc-auto-sender [--name <participant's name{VeIpcAutoSender}>]\n"
              << "  [--registry-uri silkit://<host{localhost}>:<port{8501}>]\n"
              << "  [--log <Trace|Debug|Warn|{Info}|Error|Critical|Off>]\n"
              << "  [--payload-size <number of bytes{4}>]\n"
              << "\n"
              << "Example:\n"
              << "  sil-kit-demo-veipc-auto-sender --payload-size 8\n";
}

std::string PrintBytes(std::vector<uint8_t> bytes, size_t offset /* used for SIL Kit deserialization header*/ = 0)
{
    std::ostringstream oss;
    for (size_t i = offset; i < bytes.size(); ++i)
    {
        oss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(bytes[i]) << " ";
    }
    return oss.str();
}

std::vector<uint8_t> GenerateRandomPayload(size_t size)
{
    static constexpr uint8_t maxValue = std::numeric_limits<uint8_t>::max();
    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_int_distribution<> distrib(0, maxValue);
    
    std::vector<uint8_t> payload(size);
    for (size_t i = 0; i < size; ++i)
    {
        payload[i] = static_cast<uint8_t>(distrib(gen));
    }
    return payload;
}

int main(int argc, char** argv)
{
    if (findArg(argc, argv, "--help", argv) != nullptr)
    {
        PrintHelp();
        return CodeSuccess;
    }

    const std::string participantName = getArgDefault(argc, argv, participantNameArg, "VeIpcAutoSender");
    const std::string registryUri = getArgDefault(argc, argv, regUriArg, "silkit://localhost:8501");
    const std::string loglevel = getArgDefault(argc, argv, logLevelArg, "Info");
    const size_t payloadSize = std::stoul(getArgDefault(argc, argv, "--payload-size", "4"));

    const std::string publishTopic = "toSocket";
    const std::string subscribeTopic = "fromSocket";

    if (payloadSize == 0 || payloadSize > std::numeric_limits<uint16_t>::max())
    {
        std::cerr << "[Error] Payload size must be between 1 and " << std::numeric_limits<uint16_t>::max() << " bytes" << std::endl;
        return CodeErrorOther;
    }

    try
    {
        const std::string participantConfigurationString =
            R"({ "Logging": { "Sinks": [ { "Type": "Stdout", "Level": ")" + loglevel + R"("} ] } })";

        auto participantConfiguration =
            SilKit::Config::ParticipantConfigurationFromString(participantConfigurationString);

        auto participant = SilKit::CreateParticipant(participantConfiguration, participantName, registryUri);

        auto logger = participant->GetLogger();

        PubSubSpec pubSpec(publishTopic, SilKit::Util::SerDes::MediaTypeData());
        auto dataPublisher = participant->CreateDataPublisher(participantName + "_pub", pubSpec);

        PubSubSpec subSpec(subscribeTopic, SilKit::Util::SerDes::MediaTypeData());
        auto dataSubscriber = participant->CreateDataSubscriber(
            participantName + "_sub", subSpec,
            [&](IDataSubscriber* /*subscriber*/, const DataMessageEvent& dataMessageEvent) {
                std::string bytesStr = PrintBytes(SilKit::Util::ToStdVector(dataMessageEvent.data), silkitHeaderSize);
                logger->Info("Adapter >> AutoSender: " + bytesStr);
            });

        logger->Info("Starting to send random " + std::to_string(payloadSize) + "-byte payloads every 2 seconds...");
        logger->Info("Press CTRL + C to stop the process...");

        // delay for SIL Kit environment setup
        std::this_thread::sleep_for(std::chrono::seconds(1));

        // send random payloads
        while (true)
        {
            std::vector<uint8_t> payload = GenerateRandomPayload(payloadSize);

            std::string bytesStr = PrintBytes(payload);
            logger->Info("AutoSender >> Adapter: " + bytesStr);
            
            SilKit::Util::SerDes::Serializer serializer;
            serializer.Serialize(payload);
            dataPublisher->Publish(serializer.ReleaseBuffer());

            std::this_thread::sleep_for(std::chrono::seconds(2));
        }
    }
    catch (const SilKit::ConfigurationError& error)
    {
        std::cerr << "[Error] Invalid configuration: " << error.what() << std::endl;
        return CodeErrorConfiguration;
    }
    catch (const std::exception& error)
    {
        std::cerr << "[Error] Something went wrong: " << error.what() << std::endl;
        return CodeErrorOther;
    }

    return CodeSuccess;
}
