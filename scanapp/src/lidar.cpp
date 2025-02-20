#include "lidar.h"

#include "sl_lidar.h" 

#include <cmath>
#include <sstream>

CoordinatePoint ScanPoint::to_coordinates(double scan_angle) {
    double z = std::sin(angle) * distance;
    double d2 = std::cos(angle) * distance;
    double y = std::sin(scan_angle) * d2;
    double x = std::cos(scan_angle) * d2;
    return {x,y,z};
}

void RPLidar::disconnect() {
    lidar->disconnect();
    lidar = nullptr;
    channel = nullptr;
}

bool RPLidar::connect() {
    auto channel_opt = sl::createSerialPortChannel(port, baud);
    if (!channel_opt) {
        return false;
    }
    this->channel = std::unique_ptr<sl::IChannel>{channel_opt.value};
    this->lidar = std::unique_ptr<sl::ILidarDriver>{sl::createLidarDriver().value};

    if (SL_IS_FAIL(lidar->connect(channel.get()))) {
        lidar = nullptr;
        channel = nullptr;
        return false;
    }
    return true;
}

std::string RPLidar::device_info() const {
    sl_lidar_response_device_info_t info;
    if (SL_IS_FAIL(lidar->getDeviceInfo(info))) {
        return "";
    }
    std::stringstream ss;
    ss << "Model: " << info.model 
       << " Version: " << info.hardware_version 
       << " Firmware: " << (info .firmware_version >> 8) << "." << (info.firmware_version & 0xffu);
    return ss.str();
}

std::vector<ScanPoint> RPLidar::scan(std::size_t num_points) {
    std::vector<sl_lidar_response_measurement_node_hq_t> pointbuff;
    std::vector<ScanPoint> result;

    if (!*this) {
        return {};
    }

    pointbuff.reserve(num_points);
    result.reserve(num_points);

    // TODO: this may get old scan data, as data is continously sent
    // (also tests indicate that itÄs to fast to be a full scan each call)
    // So instead probably better solution would be to introduce a scanning thread
    // which continuously updates a buffer, and after rotation, we wait until the whole
    // buffer has been refreshed
    lidar->grabScanDataHq(pointbuff.data(), num_points);
    
    for (auto p : pointbuff) {
        result.emplace_back(ScanPoint{
            p.angle_z_q14 * 90. / (1 << 14),
            p.dist_mm_q2 / 1000.,
            p.quality
        });
    }

    return result;
};
