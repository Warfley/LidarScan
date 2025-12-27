#pragma once

#include <thread>
#include <mutex>
#include <vector>
#include <deque>
#include <cstdint>
#include <string>
#include <iostream>
#include <optional>
#include <atomic>
#include <functional>

#include "lidar.h"
#include "servo.h"

struct ScanArgs {
    std::string lidar_port;
    std::string servo_port;
    double max_distance=32;
    double low_angle=0;
    double high_angle=360;
    double start=0;
    double stop=180;
    double step=1;
    double rotations=1;
    bool continuous=false;
    bool verbose=false;
};

class PointScan {
public:
    struct Slice {
        double degree;
        std::vector<ScanPoint> points;
    };
private:
    std::thread scan_thread;
    std::mutex data_mutex;
    std::deque<Slice> slices;

    RPLidar lidar;
    Servo servo;

    ScanArgs args;

    std::atomic_bool is_running = false;
    std::atomic_bool terminated = false;
public:
    PointScan(ScanArgs const &args) :
        lidar{args.lidar_port},
        servo(args.servo_port) {
        
        if (args.verbose) {
            servo.pipe_output(&std::cout);
        }

        this->args=args;
    }
    ~PointScan() {
        lidar.stop_scan();
        servo.set_degree(0);
    }

    bool connect(void);

    std::uint32_t points_per_scan(void) const {
        return (std::uint32_t)((1000000./lidar.scan_mode->us_per_sample) / lidar.rotation_frequency * args.rotations);
    }

    std::size_t max_slices(void) const  {
        return static_cast<std::size_t>((args.stop-args.start)/args.step);
    }

    bool running(void) const {
        return this->is_running.load();
    }

    void start(void);

    void stop(void) {
        terminated=true;
    }

    void wait_for(void) {
        if (scan_thread.joinable()) {
            scan_thread.join();
        }
    }

    template <typename T>
    T process_data(std::function<T(std::deque<Slice>&)> f) {
        std::lock_guard<std::mutex> lock(data_mutex);
        return f(slices);
    }

private:
    void fetch_thread(void);
};