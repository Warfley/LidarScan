
#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <fstream>

#include "servo.h"
#include "lidar.h"

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
    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << "OUTPUT_FILE LIDAR_PORT SERVO_PORT [RangeStart] [RangeEnd] [StepSize]" << std::endl;
        return 1;
    }
    std::string output_file{argv[1]};
    std::string lidar_port{argv[2]};
    std::string servo_port{argv[3]};
    double range_start = 0;
    double range_end = 180;
    double step_size = 1;
    if (argc >= 5 && (!parse_float(argv[4], &range_start) || range_start > 180)) {
        std::cerr << "Scanning range must be between 0 and 180, invalid value " << argv[4] << std::endl;
        return 1;
    }
    if (argc >= 6 && (!parse_float(argv[5], &range_end) || range_end > 180 || range_end <= range_start)) {
        std::cerr << "Scanning range must be between 0 and 180, invalid value " << argv[5] << std::endl;
        return 1;
    }
    if (argc >= 7 && !parse_float(argv[6], &step_size)) {
        std::cerr << "Invalid step size " << argv[6] << std::endl;
        return 1;
    }

    RPLidar lidar(lidar_port);
    if (!lidar.connect()) {
        std::cerr << "Error connecting to Lidar at " << lidar_port << std::endl;
        return 1;
    }

    auto device = lidar.device_info();
    if (!device) {
        std::cerr << "Couldn't detect lidar model information" << std::endl;
        return 1;
    }
    std::cout << "Detected Lidar " << *device << std::endl;

    Servo servo(servo_port);
    if (!servo.connect()) {
      std::cerr << "Error opening serial port " << servo_port << std::endl;
      return 1;
    }
    servo.pipe_output(&std::cout);

    std::ofstream outp(output_file);
    outp << "{\n"
         << "  \"start\": " << range_start << ",\n"
         << "  \"stop\": "  << range_end   << ",\n"
         << "  \"step\": "  << step_size   << ",\n"
         << "  \"points\": [\n";
    lidar.start_scan();
    std::cout << "Scanning range: " << range_start << "° to " << range_end << "° in steps of " << step_size << "°" << std::endl;
    for (double d=range_start;d<=range_end;d+=step_size) {
        servo.set_degree(d);
        std::cout << "Scanning at " << d << "°... ";
        std::cout.flush();
        // Wait for the servo to move
        // FIXME: is this too long?
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        // Grab frame
        // FIXME: how many rotations should we grab (1 rotation ~1.5k points)
        auto points = lidar.next_frame();
        if (!points) {
            std::cout << "fail... try again" << std::endl;
            d-=step_size;
            continue;
        }
        for (std::size_t i=0;i<points->size();++i) {
            auto p = points.value()[i];
            outp << "    {\n";
            outp << "      \"pitch\": "    << p.angle << ",\n"
                 << "      \"yaw\": "      << d << ",\n"
                 << "      \"distance\": " << p.distance << ",\n"
                 << "      \"quality\": "  << static_cast<int>(p.quality) << "\n"
                 << "    }";
            if (i<points->size()-1) {
                outp << ",\n";
            }
        }
        if (d+step_size<=range_end) {
            outp << ",\n";
        }
    }
    outp << "\n"
         << "  ]\n"
         << "}";
    lidar.stop_scan();

    // Return to base position
    servo.set_degree(0);

    return 0;
}
