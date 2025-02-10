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

static char const *TAG = "Servo Control";

typedef struct {
    ledc_timer_config_t timer;
    ledc_channel_config_t channel;
    int start;
    int stop;
} pwm_config_t;

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

void set_degree(pwm_config_t const *config, double d) {
    int value = (int)(d/180 * (config->stop-config->start) + config->start);
    update_pwm(&config->channel, value);
    ESP_LOGI(TAG, "Updateing to %f (%d)", d, value);
}

void pwm_loop(pwm_config_t const *config) {
    double d = 0;
    while (1) {
        set_degree(config, d);
        d += 0.5;
        if (d>180) {
            d=0;
        }
        vTaskDelay(100/portTICK_PERIOD_MS);
    }
}

void app_main(void) {
    pwm_config_t config;

    ESP_LOGI(TAG, "Testing PWM fade");
    config.timer = setup_timer(50,true);
    config.channel = setup_channel(&config.timer, 18);
    config.start = 1200;
    config.stop = 7800; // 8600 max but overshoots

    pwm_loop(&config);
}
