#pragma once

#include <ostream>
#include <string>
#include <cstdint>
class Servo {
private:
    std::string const port;
    std::int32_t const baud;
    int fd = -1;
    std::ostream *output = nullptr;
private:
    void handle_output();

public:
    Servo(std::string const &_port, std::int32_t _baud=115200) : port(_port), baud(_baud){ }
    ~Servo() { disconnect(); }
    Servo &operator =(Servo const &) = delete;

    void disconnect();

    bool connect();

    bool set_degree(double degree);

    operator bool() const { return fd >= 0; }
    std::string const &port_name() const { return port; }
    std::int32_t baud_rate() const { return baud; }
    void pipe_output(std::ostream *output) { this->output = output; }
};
