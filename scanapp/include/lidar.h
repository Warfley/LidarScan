#pragma once

#include "sl_lidar_driver.h"

#include <memory>
#include <string>
#include <cstdint>
#include <vector>
#include <optional>

struct CoordinatePoint {
    double x, y, z;
};

struct ScanPoint {
    double angle;
    double distance;
    std::uint8_t quality;

    CoordinatePoint to_coordinates(double scan_angle);
};

class RPLidar {
private:
    std::string const port;
    std::int32_t const baud;

    std::unique_ptr<sl::IChannel> channel;
    std::unique_ptr<sl::ILidarDriver> lidar;

    std::optional<sl::LidarScanMode> scan_mode;
    double rotation_frequency = 0;

public:
    RPLidar(std::string const &_port, std::int32_t _baud=115200) : port(_port), baud(_baud) {}

    void disconnect();
    bool connect();

    std::optional<std::vector<sl::LidarScanMode>> scan_modes() const {
        if (!can_request()) {
            return {};
        }
        std::vector<sl::LidarScanMode> result;
        lidar->getAllSupportedScanModes(result);
        return result;
    }

    std::optional<sl::LidarScanMode> default_scan_mode() {
        if (!can_request()) {
            return {};
        }
        std::uint16_t result;
        lidar->getTypicalScanMode(result);
        return scan_modes().value()[result];
    }

    std::optional<std::string> device_info() const;

public:
    bool start_scan();
    bool start_scan(sl::LidarScanMode const &mode);

    bool stop_scan();


    std::optional<std::vector<ScanPoint>> next_frame(int rotations=1);

    bool is_scanning() const { return !!scan_mode; }
    bool is_connected() const { return !!channel && !!lidar && lidar->isConnected(); }
    bool can_request() const { return is_connected() && !is_scanning(); }
    operator bool() const { return is_connected(); }
    std::string const &port_name() const { return port; }
    std::int32_t baud_rate() const { return baud; }

    sl::ILidarDriver &get_lidar() const { return *this->lidar; }
};
