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
    if (!is_connected()) {
        return;
    }
    if (is_scanning()) {
        stop_scan();
    }
    lidar->disconnect();
    lidar = nullptr;
    channel = nullptr;
}

bool RPLidar::connect() {
    if (is_connected()) {
        return false;
    }
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

std::optional<std::string> RPLidar::device_info() const {
    if (!can_request()) {
        return {};
    }
    sl_lidar_response_device_info_t info;
    if (SL_IS_FAIL(lidar->getDeviceInfo(info))) {
        return {};
    }
    std::stringstream ss;
    ss << "Model: " << info.model 
       << " Version: " << info.hardware_version 
       << " Firmware: " << (info .firmware_version >> 8) << "." << (info.firmware_version & 0xffu);
    return ss.str();
}

std::optional<std::vector<ScanPoint>> RPLidar::next_frame(int rotations) {
    if (!is_connected() || !is_scanning()) {
        return {};
    }
    static constexpr std::size_t BUFF_SIZE = 2048;
    auto remaining = (std::size_t)((1000000./scan_mode->us_per_sample) / rotation_frequency * rotations);
    sl_lidar_response_measurement_node_hq_t buff[BUFF_SIZE];
    std::vector<ScanPoint> result;

    result.reserve(remaining);

    // FIXME: Do I need to throw away the first batch because it may be outdated?
    while (remaining > 0) {
        // read buffer or less
        auto scan_count = remaining > BUFF_SIZE
                        ? BUFF_SIZE
                        : remaining;
        auto res = lidar->grabScanDataHq(buff, scan_count);

        if (SL_IS_FAIL(res)) {
            return {};
        }

        for (std::size_t i=0; i<scan_count; ++i) {
            result.emplace_back(ScanPoint{
                buff[i].angle_z_q14 * 90. / (1<<14),
                buff[i].dist_mm_q2 / 1000.,
                buff[i].quality
            });
        }
        remaining -= scan_count;
    }
    return result;
}

bool RPLidar::start_scan() {
    if (!can_request()) {
        return false;
    }
    sl::LidarMotorInfo motor_info;
    sl::LidarScanMode selected_mode;
    auto res = lidar->getMotorInfo(motor_info);
    if (SL_IS_FAIL(res)) {
        return false;
    }
    res = lidar->startScan(false, true, 0, &selected_mode);
    if (SL_IS_FAIL(res)) {
        return false;
    }
    scan_mode=selected_mode;
    rotation_frequency = motor_info.desired_speed/60.;
    return true;
}

bool RPLidar::start_scan(sl::LidarScanMode const &mode) {
    if (!can_request()) {
        return false;
    }
    sl::LidarMotorInfo motor_info;
    sl::LidarScanMode selected_mode;
    auto res = lidar->getMotorInfo(motor_info);
    if (SL_IS_FAIL(res)) {
        return false;
    }
    res = lidar->startScanExpress(false, mode.id, 0, &selected_mode);
    if (SL_IS_FAIL(res)) {
        return false;
    }
    scan_mode=selected_mode;
    rotation_frequency = motor_info.desired_speed/60.;
    return true;
}

bool RPLidar::stop_scan() {
    if (!is_scanning()) {
        return false;
    }
    lidar->stop();
    scan_mode = {};
    rotation_frequency = 0;
    return true;
}

