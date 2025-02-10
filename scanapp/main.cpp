#include "sl_lidar.h" 
#include "sl_lidar_driver.h"

#include <iostream>
#include <memory>

using namespace sl;

constexpr auto SERIAL_PORT = "/dev/ttyUSB0";

int main(int argc, char const **argv) {
    Result<IChannel *> chopt = createSerialPortChannel(SERIAL_PORT, 115200);
    if (!chopt) {
      std::cerr << "Error operaning serial port " << SERIAL_PORT << std::endl;
      return 1;
    }
    std::unique_ptr<IChannel> channel(*chopt);
    std::unique_ptr<ILidarDriver> lidar(*createLidarDriver());
    auto res = lidar->connect(channel.get());
    if (SL_IS_OK(res)) {
        sl_lidar_response_device_info_t deviceInfo;
        res = lidar->getDeviceInfo(deviceInfo);
        if(SL_IS_OK(res)){
            std::cout << "Model: " << deviceInfo.model 
                      << "Firmware Version: " << (deviceInfo.firmware_version >> 8) << "." << (deviceInfo.firmware_version & 0xffu)
                      << std::endl;
        } else{
            std::cerr << "Failed to get device information from LIDAR " << res << std::endl;
        }
    } else {
        std::cerr << "Failed to connect to LIDAR " << res << std::endl;
    }
    
    return 0;
}
