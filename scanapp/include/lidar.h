#pragma once

#include "sl_lidar_driver.h"

#include <memory>
#include <string>
#include <cstdint>
#include <vector>

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

public:
    RPLidar(std::string const &_port, std::int32_t _baud=115200) : port(_port), baud(_baud) {}

    void disconnect();
    bool connect();

    std::vector<sl::LidarScanMode> scan_modes() const {
        std::vector<sl::LidarScanMode> result;
        lidar->getAllSupportedScanModes(result);
        return result;
    }

    sl::LidarScanMode default_scan_mode() {
        std::uint16_t result;
        lidar->getTypicalScanMode(result);
        return scan_modes()[result];
    }

    bool start_scan() {
        return SL_IS_OK(lidar->startScan(0, true));
    }

    bool start_scan(sl::LidarScanMode const &scan_mode) {
        return SL_IS_OK(lidar->startScanExpress(false, scan_mode.id));
    }

    std::string device_info() const;

    std::vector<ScanPoint> scan(std::size_t num_points = 8192);

    operator bool() const { return (!!channel && !!lidar && lidar->isConnected() ); }
    std::string const &port_name() const { return port; }
    std::int32_t baud_rate() const { return baud; }

    sl::ILidarDriver &get_lidar() const { return *this->lidar; }
};
