#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/ledc.h"

#include "esp_system.h"
#include "esp_log.h"
#include "esp_err.h"

#define MIN_VAL 500
#define MAX_VAL 9000

#define DEFAULT_START 1200
#define DEFAULT_STOP 7800

static char const *TAG = "Servo Control";

ledc_timer_config_t setup_timer(uint32_t freq, bool highspeed) {
    static int timer_id = 0;
    ESP_ERROR_CHECK(timer_id>=LEDC_TIMER_MAX);
    ESP_LOGI(TAG, "Setup Timer %d for PWM with resolution 1024", timer_id);
    ledc_timer_config_t conf = {
        .speed_mode = highspeed ? LEDC_HIGH_SPEED_MODE : LEDC_LOW_SPEED_MODE,
        .duty_resolution = LEDC_TIMER_16_BIT,
        .timer_num = timer_id++,
        .freq_hz = freq,
        .clk_cfg = LEDC_AUTO_CLK
    };
    ESP_ERROR_CHECK(ledc_timer_config(&conf));
    return conf;
}

ledc_channel_config_t setup_channel(ledc_timer_config_t const *timer, int pinno) {
    static int hs_channel_id = 0;
    static int ls_channel_id = 0;
    int * const channel_id = timer->speed_mode==LEDC_HIGH_SPEED_MODE
                         ? &hs_channel_id
                         : &ls_channel_id;
    ESP_ERROR_CHECK(*channel_id >= LEDC_CHANNEL_MAX);
    ESP_LOGI(TAG, "Setup PIN %d for PWM", pinno);
    ledc_channel_config_t config = {
        .gpio_num = pinno,
        .speed_mode = timer->speed_mode,
        .channel = (*channel_id)++,
        .intr_type = LEDC_INTR_DISABLE,
        .timer_sel = timer->timer_num,
        .duty = 0,
        .hpoint = 0,
    };
    ledc_channel_config(&config);
    return config;
}

static inline void update_pwm(ledc_channel_config_t const *channel, uint32_t value) {
    ESP_ERROR_CHECK(ledc_set_duty(channel->speed_mode,channel->channel,value));
    ESP_ERROR_CHECK(ledc_update_duty(channel->speed_mode,channel->channel));
}

static inline void set_degree(ledc_channel_config_t const *channel,
                              uint16_t start, uint16_t stop,
                              double degree) {
    int value = (int)(degree/180 * (stop-start) + start);
    update_pwm(channel, value);
    ESP_LOGI(TAG, "Updateing to %f (%d)", degree, value);
}

static char next_char(bool peek) {
    static char buff = '\0';
    static bool hasbuff = false;
    if (!hasbuff) {
        for (;fread(&buff, sizeof(buff), 1, stdin)!=1;vTaskDelay(100/portTICK_PERIOD_MS));
        printf("%c", buff);
        fflush(stdout);
    }
    // If peeking keep buffer
    hasbuff = peek;
    return buff;
}

static inline void discard_rest_of_line(void) {
    for (char c=0;c!='\n';c=next_char(false));
}

int read_line(char *buff, int buff_len) {
    int result = 0;
    for (;result<buff_len-1;++result) {
        char c = next_char(false);
        if (c=='\n') {
            buff[result]='\0';
            return result;
        } else {
            buff[result]=c;
        }
    }
    // Last element must be \0
    buff[buff_len-1] = '\0';
    if (next_char(true)=='\n') {
        // fits exactly buffer
        next_char(false);
        return buff_len-1;
    }
    discard_rest_of_line();
    return -1;
}

static inline void skip_spaces(void) {
    for(char c=next_char(true);c==' ';c=next_char(true)) {
        next_char(false);
    }
}

int read_token(char *buff, int buff_len) {
    int result = 0;
    skip_spaces();
    for (;result<buff_len-1;++result) {
        char c = next_char(true);
        if ((c>='A' && c<='Z') ||
            (c>='a' && c <= 'z')) {
            buff[result]=c;
            // consume
            next_char(false);
        } else {
            buff[result]='\0';
            return result;
        }
    }
    // buffer to small
    buff[buff_len-1] = '\0';
    return -1;
}

bool read_float(double *d) {
    bool infrac = false;
    bool result = false;
    int part = 0;
    int base = 1;
    skip_spaces();
    while (true) {
        char c = next_char(true);
        if (c>='0' && c<='9') {
            part = part * 10 + (int)(c-'0');
            base *= 10;
        } else if (c=='.' && !infrac) {
            *d = part;
            part = 0;
            base = 1;
            infrac=true;
        } else {
            if (infrac) {
                *d += (double)part / base;
            } else {
                *d = part;
            }
            break;
        }
        // Consume char if no early return
        next_char(false);
        result = true;
    }
    return result;
}

bool read_int(int *i) {
    bool result = false;
    *i = 0;
    skip_spaces();
    while (true) {
        char c = next_char(true);
        if (c>='0' && c<='9') {
            *i = *i * 10 + (int)(c-'0');
        } else {
            break;
        }
        // Consume char if no early return
        next_char(false);
        result = true;
    }
    return result;
}

static inline bool consume_eol(const char *cmd) {
    if (next_char(false)!='\n') {
        printf("Unknown parameter for command %s\n", cmd);
        discard_rest_of_line();
        return false;
    }
    return true;
}

int32_t binary_search(ledc_channel_config_t const *channel,
                   uint16_t start, uint16_t stop) {
    char buff[2];
    if (start < MIN_VAL || stop >= MAX_VAL) {
        ESP_LOGE(TAG, "Invalid binary search range [%d..%d]", start, stop);
        return -1;
    }
    printf("Starting binary search [%d..%d]\n", start, stop);
    while (start < stop) {
        uint16_t current = (stop-start) / 2 + start;
        printf("Setting motor to %d", current);
        update_pwm(channel, current);
        printf("More (+), Less (-), accept (a) or Cancel (c)\n");
        if (read_line(buff, sizeof(buff)) != 1) {
            printf("Unknown command\n");
            continue;
        }
        switch (buff[0]) {
            case '+':
                start = current;
                break;
            case '-':
                stop = current;
                break;
            case 'a':
                start = current;
                break;
            case 'c':
                printf("Canceled binary search\n");
                return -1;
            default:
                printf("Unknown command %s\n", buff);
        }
    }
    printf("Binary search finished, result: %d\n", start);
    return start;
}

void command_loop(ledc_channel_config_t const *channel) {
    // Consider using NVS instead?
    uint16_t start = DEFAULT_START;
    uint16_t stop = DEFAULT_STOP;
    char buff[16];
    ESP_LOGI(TAG, "Starting servo control interface with range [%d..%d]", start, stop);
    set_degree(channel, start, stop, 0);
    while (true) {
        printf("|>");
        fflush(stdout);
        if (read_token(buff,sizeof(buff))<0) {
            printf("Invalid commad, type help for list of commands\n");
            discard_rest_of_line();
            continue;
        }
        if (!strncmp(buff, "set",sizeof(buff))) {
            double target;
            if (!read_float(&target)) {
                printf("Invalid degree argument for 'set', type help for list of commands\n");
                discard_rest_of_line();
                continue;
            }
            if (!consume_eol("set")) {
                continue;
            }
            set_degree(channel, start, stop, target);
        } else if (!strncmp(buff, "calibrate",sizeof(buff))) {
            if (read_token(buff,sizeof(buff))<0 || (
                    strncmp(buff, "start", sizeof(buff)) &&
                    strncmp(buff, "stop", sizeof(buff))
                )) {
                printf("Invalid target argument for 'calibrate', type help for list of commands\n");
                discard_rest_of_line();
                continue;
            }
            int cstart, cstop;
            if (!read_int(&cstart) || !read_int(&cstop)) {
                printf("Invalid range argument for 'calibrate', type help for list of commands\n");
                discard_rest_of_line();
                continue;
            }
            if (!consume_eol("calibrate")) {
                continue;
            }
            int res = binary_search(channel, cstart, cstop);
            if (res < 0) {
                continue;
            }
            if (!strncmp(buff, "start", sizeof(buff))) {
                ESP_LOGI(TAG, "Updating start range to %d, consider changing the source to make this permanent (yes I know about NVS)", res);
                start = res;
            } else {
                ESP_LOGI(TAG, "Updating stop range to %d, consider changing the source to make this permanent (yes I know about NVS)", res);
                stop = res;
            }
            set_degree(channel, start, stop, 0);
        } else if (!strncmp(buff, "help", sizeof(buff))) {
            printf("Commands:\n"
                   "  set [Degree:Float]\n"
                   "    Sets the motor to a certain degree\n"
                   "  calibrate [start|stop] [RStart:Int] [REnd:Int]\n"
                   "    Calibrates start/stop point using binary search in range RStart..REnd\n");
            discard_rest_of_line();
        } else if (buff[0]) {
            printf("Unknown command %s, type help for list of commands\n", buff);
            discard_rest_of_line();
        } else {
            discard_rest_of_line();
        }
    }
}

void app_main(void) {
    ledc_timer_config_t timer;
    ledc_channel_config_t channel;

    ESP_LOGI(TAG, "Testing PWM fade");
    timer = setup_timer(50,true);
    channel = setup_channel(&timer, 18);
    command_loop(&channel);
}
