#pragma once
#include <Arduino.h>

// 嘉顺电子 ESP32-S3 CAM 常见 DVP/OV2640 复用定义；烧录前必须对照板卡丝印/原理图复核。
#define CAM_PIN_PWDN -1
#define CAM_PIN_RESET -1
#define CAM_PIN_XCLK 15
#define CAM_PIN_SIOD 4
#define CAM_PIN_SIOC 5
#define CAM_PIN_D7 16
#define CAM_PIN_D6 17
#define CAM_PIN_D5 18
#define CAM_PIN_D4 12
#define CAM_PIN_D3 10
#define CAM_PIN_D2 8
#define CAM_PIN_D1 9
#define CAM_PIN_D0 11
#define CAM_PIN_VSYNC 6
#define CAM_PIN_HREF 7
#define CAM_PIN_PCLK 13

// 外设引脚：避开 USB GPIO19/20 与摄像头、Flash/PSRAM 资源。
#define PIN_MOTOR_LEFT 2
#define PIN_MOTOR_RIGHT 3
#define PIN_MIC_ADC 1                 // ADC1 输入，MAX9814 OUT
#define PIN_LU6288_RX 41              // ESP32 TX -> 模块 RX
#define PIN_LU6288_TX 42              // 模块 TX -> ESP32 RX（不用可悬空）
#define PIN_OLED_SDA 39
#define PIN_OLED_SCL 40
#define WIFI_SSID "CHANGE_ME"
#define WIFI_PASSWORD "CHANGE_ME"
#define BACKEND_HOST "192.168.1.100"
#define BACKEND_PORT 8765
#define DEVICE_ID "qiming_hat_001"
#define DEVICE_TOKEN "change-me"
#define IMAGE_INTERVAL_MS 250
static uint32_t lastImageMs=0;
