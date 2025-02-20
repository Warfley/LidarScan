#include "servo.h"

#include <sstream>

extern "C" {
    #include <asm/termbits.h>
    #include <sys/ioctl.h>
    #include <unistd.h>
    #include <fcntl.h>
}

void Servo::handle_output() {
        char buff[1024];
        int num_bytes;
        std::size_t bytes_read;

        if (!*this) {
            return;
        }
        if (ioctl(fd, FIONREAD, &num_bytes) < 0 || num_bytes <= 0) {
            return;
        }

        do {
            bytes_read = read(fd, buff, sizeof(buff));
            if (output) {
                output->write(buff,bytes_read);
            }

        } while (bytes_read == sizeof(buff));
}

void Servo::disconnect() {
    if (fd < 0) {
        return;
    }
    close(fd);
    fd = -1;
}


bool Servo::connect() {
    struct termios tty;
    struct termios2 tty2;
    fd = open(port.c_str()  ,O_RDWR | O_NOCTTY);

    if (fd < 0) {
        return false;
    }

    // Setting termio flags
    tty.c_cflag =  CS8 | CLOCAL | CREAD;
    tty.c_oflag = 0;
    tty.c_lflag = 0;       //ICANON;
    tty.c_cc[VMIN]=0;
    tty.c_cc[VTIME]=1;     // time out every .1 sec
    if (ioctl(fd,TCSETS,&tty) < 0) {
        disconnect();
        return false;
    }

    // Using termios2 for baud rate
    if (ioctl(fd,TCGETS2,&tty2) < 0) {
        disconnect();
        return false;
    }
    tty2.c_cflag &= ~CBAUD;
    tty2.c_cflag |= BOTHER;
    tty2.c_ispeed = baud;
    tty2.c_ospeed = baud;
    if (ioctl(fd,TCSETS2,&tty2) < 0) {
        disconnect();
        return false;
    }

    // Flush anything thats currently in the buffer
    if (ioctl(fd,TCFLSH,TCIOFLUSH) < 0) {
        disconnect();
        return false;
    }

    return true;
}

bool Servo::set_degree(double degree) {
    if (!*this) {
        return false;
    }
    std::stringstream ss;
    ss << "set " << degree << "\n";

    std::size_t res = write(fd, ss.str().data(), ss.str().length());
    handle_output();
    return res == ss.str().length();
}
