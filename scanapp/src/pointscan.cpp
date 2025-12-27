#include "pointscan.h"

bool PointScan::connect(void) {
    if (!lidar.connect()) {
        std::cerr << "Error connecting to Lidar at " << args.lidar_port << std::endl;
        return false;
    }

    auto device = lidar.device_info();
    if (!device) {
        std::cerr << "Couldn't detect lidar model information" << std::endl;
        return false;
    }
    std::cout << "Detected Lidar " << *device << std::endl;

    if (!servo.connect()) {
        std::cerr << "Error opening serial port " << args.servo_port << std::endl;
        return false;
    }

    return true;
}

void PointScan::start(void) {
    lidar.start_scan();
    is_running=true;
    terminated=false;
    scan_thread=std::thread{&PointScan::fetch_thread, this};
}

void PointScan::fetch_thread(void) {
    auto start=args.start;
    auto stop=args.stop;
    auto step=args.step;
    auto rotations=args.rotations;
    auto continuous=args.continuous;

    std::cout << "Scanning range: " << start << "° to " << stop << "° in steps of " << step << "°" << std::endl;
    for (double d=start;
         !terminated.load() && (continuous || (d<=stop && d>=start));
         d+=step) {
        servo.set_degree(d);
        std::cout << "Scanning at " << d << "°... ";
        std::cout.flush();
        // Wait for the servo to move
        // FIXME: is this too long?
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        // Grab frame
        // FIXME: how many rotations should we grab (1 rotation ~1.5k points)
        auto points = lidar.next_frame(rotations);
        if (!points) {
            std::cout << "fail... try again" << std::endl;
            d-=step;
            continue;
        }
        process_data<void>([d,&points,this](auto &data) {
            while (data.size()>=max_slices()) {
                data.pop_front();
            }
            data.emplace_back(Slice{.degree=d, .points=std::move(*points)});
        });
        
        std::cout << "done" << std::endl;
        if (continuous) {
            d=step>0 ? stop : start;
            step=-step;
        }
    }
    is_running=false;
}
