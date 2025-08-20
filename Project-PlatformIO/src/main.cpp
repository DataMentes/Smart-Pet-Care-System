#include <Arduino.h>
#include "HX711.h"

HX711 scale;

#define DT_PIN 32   // HX711 DT
#define SCK_PIN 33  // HX711 SCK

void setup() {
  Serial.begin(115200);
  scale.begin(DT_PIN, SCK_PIN);

  Serial.println("Remove all weight...");
  delay(3000); // wait to stabilize
  scale.tare(20); // average 20 readings
  long offset = scale.get_offset();
  Serial.print("Offset: ");
  Serial.println(offset);

  Serial.println("Place a known weight (e.g., 500g)...");
  delay(5000); // give you time to place the weight

  long reading = scale.read_average(20);
  Serial.print("Raw reading: ");
  Serial.println(reading);

  float knownWeight = 500.0; // <-- change this to your calibration weight
  float scaleFactor = (reading - offset) / knownWeight;

  scale.set_scale(scaleFactor);

  Serial.print("Scale factor: ");
  Serial.println(scaleFactor, 6);
  Serial.println("Now you can use:");
  Serial.print("scale.set_offset(");
  Serial.print(offset);
  Serial.print("); scale.set_scale(");
  Serial.print(scaleFactor, 6);
  Serial.println(");");
}

void loop() {
  if (scale.is_ready()) {
    float weight = scale.get_units(5); // average of 5 readings
    Serial.print("Weight: ");
    Serial.println(weight, 2);
  } else {
    Serial.println("HX711 not ready");
  }
  delay(1000);
}
