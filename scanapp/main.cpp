#include "sl_lidar.h" 
#include "sl_lidar_driver.h"

#include <iostream>
#include <memory>
#include <string>

using namespace sl;

bool parse_float(char const *s, double *out) {
    int part=0;
    int base=1;
    bool infrac=false;
    *out=0;
    if (!*s) return false;
    for (;*s;++s) {
        switch(*s) {
        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            part = part * 10 + *s-'0';
            base *= 10;
            break;
        case '.':
            if (infrac) return false;
            infrac = true;
            *out=part;
            base=1;
            part=0;
            break;
        default: return false;
        }
    }
    *out = infrac
         ? *out + (double)part / base
         : part;
    return true;
}

int main(int argc, char const **argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " LIDAR_PORT SERVO_PORT [RangeStart] [RangeEnd] [StepSize]" << std::endl;
        return 1;
    }
    std::string lidar_port{argv[1]};
    std::string servo_port{argv[2]};
    double range_start = 0;
    double range_end = 180;
    double step_size = 1;
    if (argc >= 4 && (!parse_float(argv[3], &range_start) || range_start > 180)) {
        std::cerr << "Scanning range must be between 0 and 180, invalid value " << argv[3] << std::endl;
        return 1;
    }
    if (argc >= 5 && (!parse_float(argv[4], &range_end) || range_end > 180 || range_end <= range_start)) {
        std::cerr << "Scanning range must be between 0 and 180, invalid value " << argv[4] << std::endl;
        return 1;
    }
    if (argc >= 6 && !parse_float(argv[5], &step_size)) {
        std::cerr << "Invalid step size " << argv[5] << std::endl;
        return 1;
    }
    std::cout << "Scanning range: " << range_start << "° to " << range_end << "° in steps of " << step_size << "°" << std::endl;

    Result<IChannel *> chopt = createSerialPortChannel(lidar_port, 115200);
    if (!chopt) {
      std::cerr << "Error opening serial port " << lidar_port << std::endl;
      return 1;
    }
    std::unique_ptr<IChannel> channel(*chopt);
    std::unique_ptr<ILidarDriver> lidar(*createLidarDriver());
    auto res = lidar->connect(channel.get());
    if (SL_IS_FAIL(res)) {
        std::cerr << "Failed to get device information from LIDAR " << res << std::endl;
        return 1;
    }
    sl_lidar_response_device_info_t deviceInfo;
    res = lidar->getDeviceInfo(deviceInfo);
    if (SL_IS_FAIL(res)){
        std::cerr << "Failed to connect to LIDAR " << res << std::endl;
        return 1;
    }
    std::cout << "Model: " << deviceInfo.model 
                << "Firmware Version: " << (deviceInfo.firmware_version >> 8) << "." << (deviceInfo.firmware_version & 0xffu)
                << std::endl;

    return 0;
}
