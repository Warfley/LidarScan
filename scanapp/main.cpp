
#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <fstream>
#include <optional>

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

struct args {
    std::string lidar_port;
    std::string servo_port;
    std::optional<std::string> json_out;
    std::optional<std::string> binary_out;
    double start=0;
    double stop=180;
    double step=1;
    double rotations=1;
    bool verbose=false;
};

static inline std::optional<std::string> parse_argname(char const *arg) {
    if (arg[0]!='-') {
        return {};
    }
    std::string result = arg + 1 + (arg[1]=='-');
    return result == "b" ? "binary"
         : result == "j" ? "json"
         : result == "f" ? "from"
         : result == "t" ? "to"
         : result == "s" ? "step"
         : result == "r" ? "rotations"
         : result == "v" ? "verbose"
         : result;
}

std::optional<args> parse_args(int argc, char const **argv) {
    args result;
    std::string arg_name="";
    for (int i=1;i<argc;++i) {
        auto try_name = parse_argname(argv[i]);
        if (try_name) {
            if (!arg_name.empty()) {
                std::cerr << "Invalid parameter for argument --" << arg_name << std::endl;
                return {};
            }
            if (*try_name=="verbose") {
                result.verbose=true;
                continue;
            }
            arg_name = *try_name;
            continue;
        }
        if ((arg_name=="from" && !parse_float(argv[i],&result.start)) ||
            (arg_name=="to" && !parse_float(argv[i],&result.stop)) ||
            (arg_name=="step" && !parse_float(argv[i],&result.step)) ||
            (arg_name=="rotations" && !parse_float(argv[i],&result.rotations))) {
            std::cerr << "Invalid floating point value " << argv[i] << std::endl;
            return {};
        } else if (arg_name=="binary") {
            result.binary_out = std::string(argv[i]);
        } else if (arg_name=="json") {
            result.json_out = std::string(argv[i]);
        } else if (arg_name=="" && result.lidar_port.empty()) {
            result.lidar_port = std::string(argv[i]);
        } else if (arg_name=="" && result.servo_port.empty()) {
            result.servo_port = std::string(argv[i]);
        } else if (arg_name=="") {
            std::cerr << "Unknown positional argument " << argv[i] << std::endl;
            return {};
        }
        arg_name="";
    }
    if (!arg_name.empty()) {
        std::cerr << "Invalid parameter for argument --" << arg_name << std::endl;
        return {};
    }
    if (result.lidar_port.empty() || result.servo_port.empty()) {
        return {};
    }
    if (result.start<0 || result.stop>180 || result.stop < result.start || result.step<0) {
        std::cerr << "Invalid scan range " << result.start << ".." << result.stop << ":" << result.step << std::endl;
        return {};
    }
    if (result.rotations<=0) {
        std::cerr << "Invalid number of rotations per scan " << result.rotations << std::endl;
        return {};
    }
    return result;
}

void print_help(char const *exec) {
    std::cerr << "Usage: " << exec << " [OPTIONS] LIDAR_PART SERVO_PORT\n"
              << "\n"
              << "Options:\n"
              << "  -b --binary      | Output file for binary scan data\n"
              << "  -j --json        | Output file for JSON scan data\n"
              << "  -f --from        | Start of scan range in degrees (default 0)\n"
              << "  -t --to          | Stop of scan range in degrees (default 180)\n"
              << "  -s --step        | Step size of scan range in degrees (default 1)\n"
              << "  -r --rotations   | Number of rotational scans per step (default 1)\n"
              << "  -v --verbose     | Print servo terminal output to STDOUT\n"
              << "\n"
              << "Binary data format:\n"
              << "  Header:\n"
              << "  *----------------*---------------*---------------*\n"
              << "  | 'LIDARSCAN\\0' (char[10]) | Version 1 (uint32) |\n"
              << "  *------------------------------------------------*\n"
              << "  | Start (Double) | Stop (Double) | Step (Double) |\n"
              << "  *------------------------------------------------*\n"
              << "  | Rotations (Double) |  Points Per Scan (sint32) |\n"
              << "  *--------------------*---------------------------*\n"
              << "  |                    Points...                   |\n"
              << "  *------------------------------------------------*\n"
              << "  Point Format:\n"
              << "  *---------------*----------------*-------------------*----------------*\n"
              << "  |  Yaw (Double) | Pitch (Double) | Distance (Double) | Qualit (uint8) |\n"
              << "  *---------------*----------------*-------------------*----------------*\n";
}

int main(int argc, char const **argv) {
    auto args = parse_args(argc, argv);
    if (!args) {
        print_help(argv[0]);
        return 1;
    }

    RPLidar lidar(args->lidar_port);
    if (!lidar.connect()) {
        std::cerr << "Error connecting to Lidar at " << args->lidar_port << std::endl;
        return 1;
    }

    auto device = lidar.device_info();
    if (!device) {
        std::cerr << "Couldn't detect lidar model information" << std::endl;
        return 1;
    }
    std::cout << "Detected Lidar " << *device << std::endl;

    Servo servo(args->servo_port);
    if (!servo.connect()) {
      std::cerr << "Error opening serial port " << args->servo_port << std::endl;
      return 1;
    }
    servo.pipe_output(args->verbose ? &std::cout : nullptr);

    std::ofstream json_out;
    std::ofstream binary_out;

    if (args->json_out) {
        json_out.open(args->json_out.value());
    }
    if (args->binary_out) {
        binary_out.open(args->binary_out.value(), std::ios::binary);
    }

    if (json_out.is_open()) {
        json_out << "{\n"
                << "  \"start\": " << args->start << ",\n"
                << "  \"stop\": "  << args->stop  << ",\n"
                << "  \"step\": "  << args->step  << ",\n";
    }
    if (binary_out.is_open()) {
        constexpr std::size_t MAGIC_LEN=10;
        char const MAGIC[MAGIC_LEN] = "LIDARSCAN";
        std::uint32_t const version = 1;
        binary_out.write(MAGIC, MAGIC_LEN);
        binary_out.write(reinterpret_cast<char const *>(&version), sizeof(version));

        binary_out.write(reinterpret_cast<char const *>(&args->start), sizeof(args->start));
        binary_out.write(reinterpret_cast<char const *>(&args->stop), sizeof(args->stop));
        binary_out.write(reinterpret_cast<char const *>(&args->step), sizeof(args->step));
    }
    lidar.start_scan();
    auto pps = (std::uint32_t)((1000000./lidar.scan_mode->us_per_sample) / lidar.rotation_frequency * args->rotations);
    if (json_out.is_open()) {
        json_out << "  \"pps\": " << pps << ",\n"
                 << "  \"rotations\": " << args->rotations << ",\n"
                 << "  \"points\": [\n";
    }
    if (binary_out.is_open()) {
        binary_out.write(reinterpret_cast<char const *>(&args->rotations), sizeof(args->rotations));
        binary_out.write(reinterpret_cast<char const *>(&pps), sizeof(pps));
    }
    std::cout << "Scanning range: " << args->start << "° to " << args->stop << "° in steps of " << args->step << "°" << std::endl;
    for (double d=args->start;d<=args->stop;d+=args->step) {
        servo.set_degree(d);
        std::cout << "Scanning at " << d << "°... ";
        std::cout.flush();
        // Wait for the servo to move
        // FIXME: is this too long?
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        // Grab frame
        // FIXME: how many rotations should we grab (1 rotation ~1.5k points)
        auto points = lidar.next_frame(args->rotations);
        if (!points) {
            std::cout << "fail... try again" << std::endl;
            d-=args->step;
            continue;
        }
        std::cout << "done" << std::endl;
        for (std::size_t i=0;i<points->size();++i) {
            ScanPoint p = points.value()[i];
            if (json_out.is_open()) {
                json_out << "    {\n"
                         << "      \"pitch\": "    << p.pitch << ",\n"
                         << "      \"yaw\": "      << d << ",\n"
                         << "      \"distance\": " << p.distance << ",\n"
                         << "      \"quality\": "  << static_cast<int>(p.quality) << "\n"
                         << "    }";
                if (i<points->size()-1) {
                    json_out << ",\n";
                }
            }
            if (binary_out.is_open()) {
                binary_out.write(reinterpret_cast<char const *>(&d), sizeof(d));
                binary_out.write(reinterpret_cast<char const *>(&p.pitch), sizeof(p.pitch));
                binary_out.write(reinterpret_cast<char const *>(&p.distance), sizeof(p.distance));
                binary_out.write(reinterpret_cast<char const *>(&p.quality), sizeof(p.quality));
            }
        }
        if (json_out.is_open() && d+args->step<=args->stop) {
            json_out << ",\n";
        }
    }
    if (json_out.is_open()) {
        json_out << "\n"
                 << "  ]\n"
                 << "}";
    }
    lidar.stop_scan();

    // Return to base position
    servo.set_degree(0);

    return 0;
}
