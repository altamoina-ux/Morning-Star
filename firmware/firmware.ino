#include <Arduino.h>
#include "config.h"
#include "camera_manager.h"
#include "motor_controller.h"
#include "websocket_manager.h"
#include "audio_manager.h"

void setup(){
  Serial.begin(115200); delay(300);
  pinMode(PIN_MOTOR_LEFT, OUTPUT); pinMode(PIN_MOTOR_RIGHT, OUTPUT); motorsStop();
  pinMode(PIN_MIC_ADC, INPUT);
  initCamera(); initWifiAndWebSocket(); sendOnline();
  Serial.println("QimingHat firmware ready; verify GPIOs against board schematic.");
}
void loop(){
  websocketLoop();
  static uint32_t last=0;
  if(millis()-last>10000){ last=millis(); sendHeartbeat(); }
  if(millis()-lastImageMs>IMAGE_INTERVAL_MS) { lastImageMs=millis(); captureAndSendImage(); }
  handleCommands();
  delay(2);
}
