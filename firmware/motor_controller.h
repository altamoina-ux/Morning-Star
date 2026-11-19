#pragma once
#include "config.h"
inline void motorsStop(){digitalWrite(PIN_MOTOR_LEFT,LOW);digitalWrite(PIN_MOTOR_RIGHT,LOW);}
inline void vibrate(const char* d,uint16_t ms){digitalWrite(PIN_MOTOR_LEFT,!strcmp(d,"left")||!strcmp(d,"both"));digitalWrite(PIN_MOTOR_RIGHT,!strcmp(d,"right")||!strcmp(d,"both"));delay(ms);motorsStop();}
