#pragma once

// Local credentials override the shareable defaults below.
#if __has_include("config.local.h")
#include "config.local.h"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID "YOUR_WIFI_SSID"
#endif
#ifndef WIFI_PASSWORD
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#endif
#ifndef BACKEND_HOST
#define BACKEND_HOST "YOUR_PC_LAN_IP"  // Set your computer's current LAN IPv4 locally.
#endif
#ifndef BACKEND_PORT
#define BACKEND_PORT 8765
#endif
// GC0308 supports RGB565 color. Keep JPEG transport for the larger color frame.
#ifndef CAMERA_JPEG_TRANSPORT
#define CAMERA_JPEG_TRANSPORT 1
#endif
#ifndef CAMERA_COLOR_MODE
#define CAMERA_COLOR_MODE 1
#endif
#define CAMERA_JPEG_QUALITY 65
#if CAMERA_JPEG_TRANSPORT
#define CAMERA_WS_PATH "/ws/camera?device_id=esp32s3_cam_001&protocol=2&format=jpeg"
#else
#define CAMERA_WS_PATH "/ws/camera?device_id=esp32s3_cam_001&protocol=2"
#endif

// GPIO1 is reserved for the MAX9814 analog output. The motor-driver inputs
// were moved to spare digital output pins GPIO40 and GPIO41.
#define ENABLE_MOTORS 1
#define MOTOR_LEFT_PIN 40
#define MOTOR_RIGHT_PIN 41

// LU6288 is advertised as SYN6288-compatible. TX-only UART keeps the module's
// logic-level output disconnected until its voltage is verified.
#define ENABLE_TTS 1
#define TTS_UART_TX_PIN 21
#define TTS_UART_BAUD 9600U

#if CAMERA_JPEG_TRANSPORT
#define IMAGE_INTERVAL_MS 40U
#else
#define IMAGE_INTERVAL_MS 1200U
#endif
#define FRAME_ACK_TIMEOUT_MS 5000U
#define MOTOR_PULSE_MS 300U

// Preserve the user's successfully tested camera mapping (not a universal
// Ai-Thinker mapping). Confirm the board revision before changing it.
#define CAM_PWDN -1
#define CAM_RESET -1
#define CAM_XCLK 15
#define CAM_SDA 4
#define CAM_SCL 5
#define CAM_D7 16
#define CAM_D6 17
#define CAM_D5 18
#define CAM_D4 12
#define CAM_D3 10
#define CAM_D2 8
#define CAM_D1 9
#define CAM_D0 11
#define CAM_VSYNC 6
#define CAM_HREF 7
#define CAM_PCLK 13

