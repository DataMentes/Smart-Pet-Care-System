/**
 * @file main.cpp
 * @brief Firmware for an ESP32-based Smart Pet Feeder.
 *
 * @details
 * This project implements an automated pet feeder with the following features:
 * - WiFi connectivity managed by WiFiManager for easy setup.
 * - MQTT communication with a cloud broker (HiveMQ) for remote control and status monitoring.
 * - Persistent feeding schedules, configurable via MQTT and stored in non-volatile storage (NVS).
 * - Offline data buffering: Sensor readings are stored locally if the device is offline and synced
 * to the cloud upon reconnection.
 * - Real-time clock synchronized via NTP for accurate schedule execution.
 * - Hardware control for a servo motor (dispenser), LCD display, and various sensors
 * (IR for food level, water level, and a load cell for bowl weight).
 * - A simulated load cell is used for development and testing without physical hardware.
 *
 * @author [Your Name/Project Name]
 * @date August 2025
 */

// =================================================================================================
//                                     LIBRARIES
// =================================================================================================
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <ESP32Servo.h>
#include <LiquidCrystal_I2C.h>
#include <HX711.h>
#include <Preferences.h>
#include "esp_mac.h"
#include <time.h>

// =================================================================================================
//                                     SECTION 1: HARDWARE & PIN DEFINITIONS
// =================================================================================================
// --- Peripheral Pins ---
#define SERVO_PIN 4
#define IR_SENSOR_PIN 16
#define WATER_LEVEL_SENSOR_PIN 35
#define STATUS_LED_PIN 26
#define LOAD_CELL_DOUT_PIN 32
#define LOAD_CELL_SCK_PIN 33
#define WIFI_RESET_BUTTON_PIN 13
#define BUZZER_PIN 14
#define TARE_BUTTON_PIN 19

// --- LCD Display ---
#define LCD_I2C_ADDRESS 0x27
#define LCD_COLUMNS 16
#define LCD_ROWS 2

// =================================================================================================
//                                     SECTION 2: CORE CONFIGURATION CONSTANTS
// =================================================================================================
// --- Dispensing Mechanism ---
#define SERVO_OPEN_ANGLE 10
#define SERVO_CLOSE_ANGLE 90
#define SERVO_NEUTRAL_ANGLE 90
#define DISPENSE_OFFSET_GRAMS 30

// --- Scale & Measurement ---
const int NOISE_THRESHOLD = 3;                  // (جرام) أقل قيمة تغيير نعتبرها مهمة
const unsigned long STABILITY_DURATION = 5000;  // (3 ثوانٍ) مدة استقرار الوزن الجديد
const int AUTO_TARE_THRESHOLD = 5;              // (جرام) نطاق اعتبار الوعاء فارغًا
const unsigned long AUTO_TARE_DURATION = 15000; // (15 ثانية) مدة بقاء الوعاء فارغًا لتفعيل التصفير التلقائي

// --- Sensor Thresholds ---
const int WATER_LEVEL_THRESHOLD = 1350; // ADC value to determine if water is low.

// --- Timing & Intervals (in milliseconds) ---
const unsigned long MQTT_RECONNECT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const unsigned long WIFI_RECONNECT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const unsigned long LCD_UPDATE_INTERVAL_MS = 500;
const unsigned long SENSOR_PUBLISH_COOLDOWN_MS = 3 * 5 * 1000;          // 3 minutes
const unsigned long DISPENSE_TIMEOUT_MS = 20000;                        // 20 seconds
const unsigned long NTP_SYNC_INTERVAL_MS = 12UL * 60UL * 60UL * 1000UL; // 12 hours
const unsigned long WIFI_RESET_BUTTON_HOLD_MS = 5000;                   // 5 seconds
const unsigned long WEIGHT_STABILITY_TIMEOUT_MS = 5 * 2 * 1000;         // 5 minutes to confirm pet has finished eating

// =================================================================================================
//                                     SECTION 3: GLOBAL OBJECTS & TYPE DEFINITIONS
// =================================================================================================
// --- Hardware Objects ---
LiquidCrystal_I2C lcd(LCD_I2C_ADDRESS, LCD_COLUMNS, LCD_ROWS);
Servo dispenserServo;
HX711 scale;

// --- Network Objects ---
const char *MQTT_BROKER_HOST = "b8fde1f028ba4c73969c9d8905059c14.s1.eu.hivemq.cloud";
const int MQTT_BROKER_PORT = 8883;
const char *MQTT_USERNAME = "Smart-Pet-Care-System";
const char *MQTT_PASSWORD = "Smart_care_pet_system_000";
WiFiClientSecure secureWifiClient;
PubSubClient mqttClient(secureWifiClient);
WiFiManager wifiManager;

// --- Time Synchronization Objects ---
WiFiUDP ntpUdpClient;
NTPClient ntpTimeClient(ntpUdpClient, "pool.ntp.org");

// --- Non-Volatile Storage ---
Preferences preferences;

// --- Custom Data Structures ---
struct FeedingTime
{
  int hour;
  int minute;
  int grams;
  int lastExecutionDay; // Tracks the last day this schedule was run to prevent duplicates.
};

// =================================================================================================
//                                     SECTION 4: GLOBAL STATE VARIABLES
// =================================================================================================
// --- Network & MQTT State ---
char mqttClientID[18];
char mqttTopicSchedule[64];
char mqttTopicStatus[64];
char mqttTopicPetFoodConsumption[64];
char mqttTopicFeedNow[64];
unsigned long lastMqttReconnectAttemptTimestamp = 0;
unsigned long lastWifiReconnectAttemptTimestamp = 0;

// --- Motor Control State ---
enum MotorState
{
  MOTOR_IDLE,
  MOTOR_DISPENSING_TOWARD_RIGHT,
  MOTOR_DISPENSING_TOWARD_LEFT,
  MOTOR_CLOSING
};
MotorState currentMotorState = MOTOR_IDLE;
unsigned long motorStateChangeTimestamp = 0;

// --- Schedule Management ---
const int MAX_SCHEDULED_FEEDS = 8;
FeedingTime feedingSchedule[MAX_SCHEDULED_FEEDS];
int activeScheduleCount = 0;

// --- Device State & Flags ---
bool isDispensingInProgress = false;
unsigned long dispenseStartTimestamp = 0;
int dispenseTargetGrams = 0;
unsigned long wifiResetButtonPressedTimestamp = 0;
bool isWifiResetButtonHeld = false;
unsigned long lastTareButtonPress = 0;
bool isBuzzerPatternActive = false;
bool isBuzzerPatternRequested = false;

// --- Sensor State ---
int lastKnownIrState = -1;
int lastKnownWaterState = -1;
int lastPublishedWeight = 0;
unsigned long lastSensorDataPublishTimestamp = 0;

const int ANGLE_LEFT = 10;   // قرب من الحد الأدنى
const int ANGLE_RIGHT = 170; // قرب من الحد الأقصى

// وقت الانتظار – كل ما تزود هيلحق يوصل للنهاية
int stepDelay = 300; // جرّب 10..20 حسب نوع السيرفو

// --- Intelligent Scale State ---
bool isWeightStable = true;
int stableWeight = 0;
int potentialNewWeight = 0;
unsigned long unstableSince = 0;
bool isPotentiallyEmpty = false;
unsigned long nearZeroSince = 0;

// --- Pet Food Consumption State ---
bool isMonitoringConsumption = false;
int weightAfterDispensing = 0;
unsigned long lastWeightChangeTimestamp = 0;
int lastMonitoredWeight = -1;

// --- Time Management ---
unsigned long lastNtpSyncMillis = 0;
time_t lastNtpEpochTime = 0;
unsigned long lastPeriodicNtpSyncTimestamp = 0;

// --- UI State (LCD & Buzzer) ---
String lastLcdLine1 = "";
String lastLcdLine2 = "";
unsigned long lastLcdUpdateTimestamp = 0;
unsigned long buzzerPreviousMillis = 0;
int buzzerState = LOW;
int buzzerBeepCount = 0;
byte customCharArrowUp[8] = {0b00100, 0b01110, 0b10101, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000};
byte customCharArrowDown[8] = {0b00100, 0b00100, 0b00100, 0b00100, 0b10101, 0b01110, 0b00100, 0b00000};

// --- Offline Data Buffering ---
int offlineReadingsBufferedCount = 0;
const int MAX_BUFFERED_READINGS = 50;

// =================================================================================================
//                                     SECTION 5: FORWARD DECLARATIONS
// =================================================================================================
// --- Core Logic Handlers ---
void handleConfigurationRequest();
void handleNetworkTasks();
void handleDispensing();
void handleSensorAndUI();
void handleScheduleExecution();
void handleBuzzerPattern();

// --- Network & Communication ---
void initializeMqttConnection();
void onMqttMessageCallback(char *topic, byte *payload, unsigned int length);
void publishDeviceStatus(const String &message);
void publishBufferedReadings();

// --- Data Persistence & Management ---
void saveScheduleToNVS();
void loadScheduleFromNVS();
void bufferSensorReadingOffline(int irState, int waterState, int weight);
void loadOfflineReadingCount();

// --- Time Management ---
void initializeTime();
void synchronizeNTP();
time_t getCurrentEpochTime();
String getFormattedDateTimeString();

// --- Hardware Control & Utilities ---
void controlDispenserMotor(const char *state);
void updateLcdScreen(const String &line1, const String &line2);
int readBowlWeight();
void tareBowlScale();
void triggerBuzzer();
int getPositiveWeight(int samples);

// --- Schedule & Payload Helpers ---
void parseScheduleFromJson(const String &jsonPayload);
String createStatusJson(int irState, int waterState, int weight);

// =================================================================================================
//                                     SECTION 6: SETUP & MAIN LOOP
// =================================================================================================
/**
 * @brief Initializes the system, hardware, and network connections.
 * Runs once at startup.
 */
void setup()
{
  Serial.begin(115200);

  // --- Generate a unique MQTT client ID from the device's MAC address ---
  uint8_t baseMac[6];
  esp_read_mac(baseMac, ESP_MAC_WIFI_STA);
  sprintf(mqttClientID, "%02X:%02X:%02X:%02X:%02X:%02X", baseMac[0], baseMac[1], baseMac[2], baseMac[3], baseMac[4], baseMac[5]);
  Serial.print("[INIT] Device ID (MAC): ");
  Serial.println(mqttClientID);

  // --- Dynamically create MQTT topics based on the unique client ID ---
  sprintf(mqttTopicSchedule, "petfeeder/devices/%s/schedule", mqttClientID);
  sprintf(mqttTopicStatus, "petfeeder/devices/%s/status", mqttClientID);
  sprintf(mqttTopicPetFoodConsumption, "petfeeder/devices/%s/petfoodconsumption", mqttClientID);
  sprintf(mqttTopicFeedNow, "petfeeder/devices/%s/feednow", mqttClientID);

  Serial.print("[INIT] Schedule Topic: ");
  Serial.println(mqttTopicSchedule);
  Serial.print("[INIT] Status Topic: ");
  Serial.println(mqttTopicStatus);
  Serial.print("[INIT] Pet Food Consumption Topic: ");
  Serial.println(mqttTopicPetFoodConsumption);

  // --- Pin Initializations ---
  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(WIFI_RESET_BUTTON_PIN, INPUT_PULLUP);
  pinMode(TARE_BUTTON_PIN, INPUT_PULLUP);
  pinMode(IR_SENSOR_PIN, INPUT_PULLUP);
  pinMode(WATER_LEVEL_SENSOR_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // --- Real Scale Initialization ---
  scale.begin(LOAD_CELL_DOUT_PIN, LOAD_CELL_SCK_PIN);
  scale.set_scale(681.601624);
  scale.set_offset(-102160);
  scale.tare(20);
  stableWeight = getPositiveWeight(30);
  // --- Hardware Initializations ---
  lcd.init();
  lcd.backlight();
  lcd.createChar(1, customCharArrowUp);
  lcd.createChar(2, customCharArrowDown);
  dispenserServo.attach(SERVO_PIN);
  dispenserServo.write(SERVO_NEUTRAL_ANGLE);

  // --- Data Loading ---
  loadOfflineReadingCount();
  loadScheduleFromNVS();
  initializeTime(); // Loads saved time first

  // --- Network Initializations ---
  secureWifiClient.setInsecure(); // Allows connection to brokers with self-signed certs if needed.
  mqttClient.setServer(MQTT_BROKER_HOST, MQTT_BROKER_PORT);
  mqttClient.setCallback(onMqttMessageCallback);

  // --- Start a non-blocking WiFi connection attempt ---
  WiFi.mode(WIFI_STA);
  Serial.println("[INIT] System starting... Attempting initial background WiFi connection.");
  WiFi.begin();
  lastWifiReconnectAttemptTimestamp = millis();
}

/**
 * @brief The main execution loop.
 * This function is non-blocking and orchestrates all device tasks.
 */
void loop()
{
  handleMotorControl();
  // Check for a long-press on the WiFi reset button to enter configuration mode.
  handleConfigurationRequest();
  //
  handleTareButton();
  // Manage WiFi and MQTT connections, and handle incoming MQTT messages.
  handleNetworkTasks();
  // Update state for ongoing dispensing process.
  handleDispensing();
  // Handle the pet food consumption monitoring state.
  handlePetFoodConsumption();
  // Manage non-blocking buzzer pattern if requested.
  if (isBuzzerPatternRequested)
  {
    handleBuzzerPattern();
  }
  // These handlers only run if no dispensing is in progress to avoid conflicts.
  if (!isDispensingInProgress && !isMonitoringConsumption)
  {
    // Read sensors, update the LCD, and publish status changes.
    handleSensorAndUI();
    // Check the current time against the schedule to trigger feeding.
    handleScheduleExecution();

    // handleAutoTare();
  }
  // If connected to MQTT, attempt to sync any buffered offline data.
  if (mqttClient.connected())
  {
    publishBufferedReadings();
  }
}

// =================================================================================================
//                                     SECTION 7: CORE LOGIC HANDLERS
// =================================================================================================
/**
 * @brief Non-blocking handler for the dispenser motor state machine.
 * Manages the dispensing oscillation (back and forth movement).
 */
void handleMotorControl()
{
  // If the motor is idle, do nothing.
  if (currentMotorState == MOTOR_IDLE)
    return;

  unsigned long currentTime = millis();

  // Only check time if we are in an active dispensing state
  if (currentTime - motorStateChangeTimestamp < stepDelay)
  {
    return; // Not time to move yet
  }

  // Update the timestamp for the next move
  motorStateChangeTimestamp = currentTime;

  switch (currentMotorState)
  {
  case MOTOR_DISPENSING_TOWARD_RIGHT:
    // We were at LEFT, now move to RIGHT
    dispenserServo.write(ANGLE_RIGHT);
    // Set the next state to be the opposite direction
    currentMotorState = MOTOR_DISPENSING_TOWARD_LEFT;
    break;

  case MOTOR_DISPENSING_TOWARD_LEFT:
    // We were at RIGHT, now move back to LEFT
    dispenserServo.write(ANGLE_LEFT);
    // Set the next state to loop back
    currentMotorState = MOTOR_DISPENSING_TOWARD_RIGHT;
    break;

  case MOTOR_CLOSING:
    // The dispensing process is over, move to the final closed position
    dispenserServo.write(ANGLE_LEFT); // Or SERVO_CLOSE_ANGLE if you prefer
    currentMotorState = MOTOR_IDLE;   // Stop all motor activity
    Serial.println("[MOTOR FSM] Dispensing complete. Motor is now idle.");
    break;
  }
}

/**
 * @brief Monitors the WiFi reset button to trigger the WiFiManager configuration portal.
 */
void handleConfigurationRequest()
{
  if (digitalRead(WIFI_RESET_BUTTON_PIN) == HIGH)
  { // Button is pressed (active HIGH)
    if (!isWifiResetButtonHeld)
    {
      isWifiResetButtonHeld = true;
      wifiResetButtonPressedTimestamp = millis();
    }
  }
  else
  {
    isWifiResetButtonHeld = false;
  }

  if (isWifiResetButtonHeld && (millis() - wifiResetButtonPressedTimestamp > WIFI_RESET_BUTTON_HOLD_MS))
  {
    Serial.println("[WIFI] Configuration portal requested via button press.");
    updateLcdScreen("WiFi Setup Mode", "Connect to AP...");

    wifiManager.setConfigPortalTimeout(180); // 3-minute timeout
    if (wifiManager.startConfigPortal("Smart_Pet_Care_System_Config"))
    {
      Serial.println("[WIFI] Configured successfully! Rebooting...");
    }
    else
    {
      Serial.println("[WIFI] Configuration timed out. Rebooting...");
    }
    delay(2000);
    ESP.restart();
  }
}

/**
 * @brief Manages background network tasks like maintaining WiFi and MQTT connections.
 */
void handleNetworkTasks()
{
  // --- WiFi Connection Management ---
  if (WiFi.status() != WL_CONNECTED)
  {
    if (millis() - lastWifiReconnectAttemptTimestamp > WIFI_RECONNECT_INTERVAL_MS)
    {
      Serial.println("[WIFI] Attempting to reconnect to last known WiFi...");
      WiFi.begin();
      lastWifiReconnectAttemptTimestamp = millis();
    }
    return; // No further network tasks if not connected to WiFi.
  }

  // --- Periodic NTP Sync ---
  if (millis() - lastPeriodicNtpSyncTimestamp > NTP_SYNC_INTERVAL_MS)
  {
    synchronizeNTP();
    lastPeriodicNtpSyncTimestamp = millis();
  }

  // --- MQTT Connection Management ---
  initializeMqttConnection();
  mqttClient.loop(); // Process incoming messages and maintain connection.
}

/**
 * @brief Manages the state of the food dispensing process.
 * @details Uses a fast reading during dispensing to avoid timeouts, then confirms
 * the final weight with a high-quality stable reading before starting consumption monitoring.
 */
void handleDispensing()
{
  if (!isDispensingInProgress)
    return;

  unsigned long currentTime = millis();
  int currentWeight = getPositiveWeight(3);

  // --- MODIFIED LOGIC ---
  // Check if the current weight has reached the target *minus* the offset.
  // This stops the motor early to account for the food that is still falling.
  bool isTargetMet = (currentWeight >= (dispenseTargetGrams - DISPENSE_OFFSET_GRAMS));

  bool isTimeout = (currentTime - dispenseStartTimestamp > DISPENSE_TIMEOUT_MS);

  if (currentTime - lastLcdUpdateTimestamp >= LCD_UPDATE_INTERVAL_MS)
  {
    updateLcdScreen("Feeding...", "Weight: " + String(currentWeight) + "g");
    lastLcdUpdateTimestamp = currentTime;
  }

  if (isTimeout || isTargetMet)
  {
    controlDispenserMotor("close");
    isDispensingInProgress = false;

    if (isTargetMet)
    {
      Serial.printf("[DISPENSE] Target of %dg met (stopped early at %dg).\n", dispenseTargetGrams, currentWeight);
    }
    else
    {
      Serial.println("[DISPENSE] Timed out.");
    }

    // Give a very short delay for the falling food to settle before the final accurate reading
    delay(500); // 0.5 second delay

    // --- Get a final, high-quality stable reading ---
    stableWeight = getPositiveWeight(30);
    lastPublishedWeight = stableWeight;
    Serial.printf("[DISPENSE] Final stable weight after settling: %dg\n", stableWeight);

    if (WiFi.status() == WL_CONNECTED)
    {
      String finalStatus = createStatusJson(lastKnownIrState, lastKnownWaterState, stableWeight);
      publishDeviceStatus(finalStatus);
    }

    // --- START PET FOOD CONSUMPTION MONITORING ---
    Serial.println("[CONSUMPTION] Dispensing complete. Starting to monitor pet food consumption.");
    isMonitoringConsumption = true;
    weightAfterDispensing = stableWeight;
    lastMonitoredWeight = stableWeight;
    lastWeightChangeTimestamp = millis();
  }
}

/**
 * @brief Monitors the food bowl after dispensing to calculate how much the pet has eaten.
 * @details It waits for the bowl's weight to be stable for a predefined period
 * before taking a final, stable average reading to calculate and publish the consumed amount.
 */
void handlePetFoodConsumption()
{
  if (!isMonitoringConsumption)
    return;

  // Use a quick reading for monitoring
  int currentWeight = getPositiveWeight(10);

  // Check if the weight has changed significantly (i.e., the pet is eating)
  if (abs(currentWeight - lastMonitoredWeight) >= NOISE_THRESHOLD)
  {
    // If it changed, reset the stability timer
    lastWeightChangeTimestamp = millis();
  }

  // Update the last monitored weight for the next check
  lastMonitoredWeight = currentWeight;

  // Check if the weight has been stable for the required duration
  // Note: Using STABILITY_DURATION * 2 or a dedicated constant is a good idea here
  if (millis() - lastWeightChangeTimestamp > (STABILITY_DURATION * 2))
  {
    Serial.println("[CONSUMPTION] Weight has been stable. Calculating and publishing consumption.");

    // --- Get a final, high-quality stable reading to ensure accuracy ---
    int finalWeight = getPositiveWeight(30);
    stableWeight = finalWeight; // Update the global stable weight as well
    lastPublishedWeight = finalWeight;

    // Calculate the consumed amount
    int consumedGrams = weightAfterDispensing - finalWeight;
    // Ensure consumption is not negative due to scale noise/drift
    if (consumedGrams < 0)
    {
      consumedGrams = 0;
    }

    // Create JSON payload
    JsonDocument doc;
    doc["consumed_grams"] = consumedGrams;
    String payload;
    serializeJson(doc, payload);

    // Publish to the new topic
    if (mqttClient.connected())
    {
      mqttClient.publish(mqttTopicPetFoodConsumption, payload.c_str(), false);
      Serial.println("[MQTT SEND] Published pet food consumption: " + payload);
    }
    else
    {
      Serial.println("[CONSUMPTION] MQTT not connected. Could not publish consumption data.");
    }

    // --- End of monitoring cycle ---
    isMonitoringConsumption = false;
    lastMonitoredWeight = -1; // Reset for the next cycle
  }
}

/**
 * @brief Reads sensors, updates UI instantly with a raw weight,
 * and publishes a confirmed stable weight.
 * @details This function now uses a "two-speed" approach. A fast, raw reading is
 * used for immediate UI feedback, while the stability filter runs in the
 * background to determine a high-quality, stable weight for MQTT publishing.
 */
void handleSensorAndUI()
{
  // Get a very fast reading using only one sample for responsiveness
  int rawWeight = getPositiveWeight(1);
  int irState = !digitalRead(IR_SENSOR_PIN);
  int waterAdcValue = analogRead(WATER_LEVEL_SENSOR_PIN);
  int waterState = (waterAdcValue > WATER_LEVEL_THRESHOLD) ? 1 : 0;

  // --- LCD Update Logic ---
  // Update the screen immediately with the fast, raw weight reading.
  if (millis() - lastLcdUpdateTimestamp >= LCD_UPDATE_INTERVAL_MS)
  {
    String line1 = "Tank:" + String(irState ? char(1) : char(2)) + " Water:" + String(waterState ? char(1) : char(2));
    String line2 = "Weight: " + String(rawWeight) + "g"; // Display the responsive raw weight
    updateLcdScreen(line1, line2);
    lastLcdUpdateTimestamp = millis();
  }

  // --- Stability Filter Logic (for accurate MQTT publishing) ---
  // This block runs in the background to determine the official 'stableWeight'.
  if (isWeightStable)
  {
    // If the state is stable, check for a significant change that might make it unstable.
    if (abs(rawWeight - stableWeight) > NOISE_THRESHOLD)
    {
      isWeightStable = false;         // Change state to unstable/monitoring
      unstableSince = millis();       // Start the stability timer
      potentialNewWeight = rawWeight; // This is the new weight we are monitoring
    }
  }
  else
  { // If the state is already unstable...
    // Check if the weight is still fluctuating.
    if (abs(rawWeight - potentialNewWeight) > NOISE_THRESHOLD)
    {
      unstableSince = millis(); // Reset the timer if it's still changing
      potentialNewWeight = rawWeight;
    }

    // Check if the weight has been calm for the required duration.
    if (millis() - unstableSince >= STABILITY_DURATION)
    {
      // Confirm the new stable weight with a high-quality reading
      stableWeight = getPositiveWeight(20);
      isWeightStable = true; // Return to the stable state
      Serial.print("--> New stable weight confirmed for MQTT: ");
      Serial.println(stableWeight);
    }
  }

  // --- MQTT Publish Logic ---
  // Only publish if there's a real change AND the weight is confirmed to be stable.
  bool isSignificantChange = (irState != lastKnownIrState || waterState != lastKnownWaterState || stableWeight != lastPublishedWeight);
  bool isCooldownOver = (millis() - lastSensorDataPublishTimestamp > SENSOR_PUBLISH_COOLDOWN_MS);

  if (isSignificantChange && isCooldownOver && isWeightStable)
  {
    // Update the last known state variables with the new, confirmed values
    lastKnownIrState = irState;
    lastKnownWaterState = waterState;
    lastPublishedWeight = stableWeight;
    lastSensorDataPublishTimestamp = millis(); // Reset the cooldown timer

    // Publish or buffer the new state
    if (WiFi.status() == WL_CONNECTED)
    {
      String payload = createStatusJson(irState, waterState, stableWeight);
      publishDeviceStatus(payload);
    }
    else
    {
      bufferSensorReadingOffline(irState, waterState, stableWeight);
    }
  }
}

/**
 * @brief Checks the current time against the loaded schedule to initiate a feeding cycle.
 */
void handleScheduleExecution()
{
  time_t now = getCurrentEpochTime();
  if (now == 0)
    return;

  struct tm timeinfo;
  localtime_r(&now, &timeinfo);
  int currentHour = timeinfo.tm_hour;
  int currentMinute = timeinfo.tm_min;
  int dayOfYear = timeinfo.tm_yday;

  for (int i = 0; i < activeScheduleCount; i++)
  {
    if (feedingSchedule[i].hour == currentHour && feedingSchedule[i].minute == currentMinute)
    {
      if (feedingSchedule[i].lastExecutionDay != dayOfYear)
      {
        feedingSchedule[i].lastExecutionDay = dayOfYear;

        if (isDispensingInProgress || isMonitoringConsumption)
        {
          Serial.println("[WARN] Schedule match, but another process is active.");
          return;
        }

        // --- MODIFIED LOGIC TO ADD TO CURRENT WEIGHT ---
        // REMOVED: tareBowlScale();
        // REMOVED: stableWeight = 0;
        // REMOVED: lastPublishedWeight = 0;

        // ADDED: Calculate the new target based on the current stable weight.
        int amountToDispense = feedingSchedule[i].grams;
        int currentBowlWeight = getPositiveWeight(5);
        dispenseTargetGrams = currentBowlWeight + amountToDispense;

        Serial.printf("[SCHEDULE] Match found. Current: %dg, Adding: %dg, New Target: %dg\n", currentBowlWeight, amountToDispense, dispenseTargetGrams);

        isDispensingInProgress = true;
        dispenseStartTimestamp = millis();
        controlDispenserMotor("open");
        triggerBuzzer();
        break;
      }
    }
  }
}
/**
 * @brief Manages a non-blocking 3-beep buzzer pattern.
 */
void handleBuzzerPattern()
{
  if (!isBuzzerPatternActive)
  {
    // Start the pattern
    isBuzzerPatternActive = true;
    buzzerBeepCount = 0;
    buzzerState = HIGH;
    digitalWrite(BUZZER_PIN, buzzerState);
    buzzerPreviousMillis = millis();
    return;
  }

  unsigned long currentMillis = millis();
  if (currentMillis - buzzerPreviousMillis >= 500)
  { // Toggle every 0.5 seconds
    buzzerPreviousMillis = currentMillis;
    buzzerState = !buzzerState;
    digitalWrite(BUZZER_PIN, buzzerState);

    // A full beep cycle (ON -> OFF) is complete when the buzzer turns off.
    if (buzzerState == LOW)
    {
      buzzerBeepCount++;
      if (buzzerBeepCount >= 3)
      {
        isBuzzerPatternActive = false;
        isBuzzerPatternRequested = false; // Reset the request flag
        digitalWrite(BUZZER_PIN, LOW);    // Ensure it's off
      }
    }
  }
}
/**
 * @brief Triggers a manual feeding cycle.
 * @param grams The amount of food to dispense.
 */
void triggerManualFeed(int grams)
{
  if (isDispensingInProgress || isMonitoringConsumption)
  {
    Serial.println("[FEED NOW] Request ignored: a feeding or monitoring cycle is already active.");
    return;
  }
  if (grams <= 0)
  {
    Serial.println("[FEED NOW] Request ignored: grams must be a positive number.");
    return;
  }

  // ADDED: Calculate the new target based on the current stable weight.
  int amountToDispense = grams;
  int currentBowlWeight = getPositiveWeight(5);
  dispenseTargetGrams = currentBowlWeight + amountToDispense;

  Serial.printf("[FEED NOW] Manual feed. Current: %dg, Adding: %dg, New Target: %dg\n", currentBowlWeight, amountToDispense, dispenseTargetGrams);

  isDispensingInProgress = true;
  dispenseStartTimestamp = millis();
  controlDispenserMotor("open");
  triggerBuzzer();
}
// =================================================================================================
//                                     SECTION 8: NETWORK & COMMUNICATION
// =================================================================================================
/**
 * @brief Ensures the MQTT client is connected. Attempts to reconnect if necessary.
 */
void initializeMqttConnection()
{
  if (mqttClient.connected())
    return;

  if ((millis() - lastMqttReconnectAttemptTimestamp > MQTT_RECONNECT_INTERVAL_MS) || (lastMqttReconnectAttemptTimestamp == 0))
  {
    lastMqttReconnectAttemptTimestamp = millis();
    Serial.print("[MQTT] Attempting to connect...");
    if (mqttClient.connect(mqttClientID, MQTT_USERNAME, MQTT_PASSWORD))
    {
      Serial.println(" connected.");
      mqttClient.subscribe(mqttTopicSchedule);
      mqttClient.subscribe(mqttTopicFeedNow);
      ntpTimeClient.begin(); // Re-initialize NTP client after connection
    }
    else
    {
      Serial.print(" failed, rc=");
      Serial.println(mqttClient.state());
    }
  }
}

/**
 * @brief Callback function for handling incoming MQTT messages.
 * @param topic The MQTT topic the message was received on.
 * @param payload The message payload.
 * @param length The length of the payload.
 */
void onMqttMessageCallback(char *topic, byte *payload, unsigned int length)
{
  String message;
  message.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++)
  {
    message += (char)payload[i];
  }
  Serial.println("[MQTT] Message received on " + String(topic) + ": " + message);

  // --- Handle Schedule Updates ---
  if (String(topic) == mqttTopicSchedule)
  {
    preferences.begin("pet-feeder", true);
    if (preferences.getString("schedule", "[]").equals(message))
    {
      preferences.end();
      return; // No update needed if schedule is identical
    }
    preferences.end();
    parseScheduleFromJson(message);
  }
  // --- ✨ Handle "Feed Now" Requests ---
  else if (String(topic) == mqttTopicFeedNow)
  {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, message);

    if (err)
    {
      Serial.println("[FEED NOW] Failed to parse JSON payload.");
      return;
    }

    if (!doc.containsKey("grams") || !doc["grams"].is<int>())
    {
      Serial.println("[FEED NOW] Invalid payload. Expecting JSON with an integer 'grams' key.");
      return;
    }

    int gramsToFeed = doc["grams"];
    triggerManualFeed(gramsToFeed);
  }
}

/**
 * @brief Publishes a status message to the MQTT status topic.
 * @param message The string message to publish.
 */
void publishDeviceStatus(const String &message)
{
  if (mqttClient.connected())
  {
    mqttClient.publish(mqttTopicStatus, message.c_str(), false);
    Serial.println("[MQTT SEND] " + message);
  }
  else
  {
    Serial.println("[MQTT WARN] Client not connected. Cannot publish status.");
  }
}

/**
 * @brief Iterates through buffered offline readings and publishes them to MQTT.
 */
void publishBufferedReadings()
{
  if (offlineReadingsBufferedCount == 0 || !mqttClient.connected())
    return;

  Serial.println("[SYNC] Starting sync of " + String(offlineReadingsBufferedCount) + " buffered readings...");
  preferences.begin("readings", false);

  bool allSyncsSuccessful = true;
  for (int i = 0; i < offlineReadingsBufferedCount; i++)
  {
    String key = "reading_" + String(i);
    String simplePayload = preferences.getString(key.c_str(), "");
    if (simplePayload != "")
    {
      int ir, water;
      float weight;
      sscanf(simplePayload.c_str(), "%d,%d,%d", &ir, &water, &weight);
      String jsonPayload = createStatusJson(ir, water, weight);

      if (!mqttClient.publish(mqttTopicStatus, jsonPayload.c_str(), false))
      {
        Serial.println("[SYNC] Failed to publish reading #" + String(i) + ". Halting sync.");
        allSyncsSuccessful = false;
        break;
      }
      Serial.println("[SYNC] Published reading #" + String(i));
      delay(100); // Small delay to avoid flooding the broker
    }
  }

  if (allSyncsSuccessful)
  {
    Serial.println("[SYNC] All buffered readings sent. Clearing offline storage.");
    preferences.clear();
    offlineReadingsBufferedCount = 0;
    preferences.putInt("count", 0);
  }

  preferences.end();
}

// =================================================================================================
//                                     SECTION 9: DATA PERSISTENCE & MANAGEMENT
// =================================================================================================
/**
 * @brief Saves the current feeding schedule array to Non-Volatile Storage (NVS).
 */
void saveScheduleToNVS()
{
  preferences.begin("pet-feeder", false);
  JsonDocument doc;
  JsonArray array = doc.to<JsonArray>();
  for (int i = 0; i < activeScheduleCount; i++)
  {
    JsonObject feed = array.add<JsonObject>();
    feed["device_id"] = mqttClientID;
    feed["food_weighted"] = feedingSchedule[i].grams;
    char timeBuffer[6];
    snprintf(timeBuffer, sizeof(timeBuffer), "%02d:%02d", feedingSchedule[i].hour, feedingSchedule[i].minute);
    feed["timestamp"] = timeBuffer;
  }
  String scheduleJson;
  serializeJson(doc, scheduleJson);
  preferences.putString("schedule", scheduleJson);
  preferences.end();
  Serial.println("[NVS] Schedule saved to non-volatile storage.");
}

/**
 * @brief Loads the feeding schedule from NVS into the global array.
 */
void loadScheduleFromNVS()
{
  preferences.begin("pet-feeder", true); // Read-only mode
  String scheduleJson = preferences.getString("schedule", "[]");
  preferences.end();

  Serial.println("[NVS] Loading schedule from non-volatile storage.");
  parseScheduleFromJson(scheduleJson);
  Serial.print("[NVS] Schedule loaded. Active items: ");
  Serial.println(activeScheduleCount);
}

/**
 * @brief Stores a single sensor reading to NVS when the device is offline.
 * @param irState The state of the IR sensor (1 or 0).
 * @param waterState The state of the water sensor (1 or 0).
 * @param weight The current weight reading.
 */
void bufferSensorReadingOffline(int irState, int waterState, int weight)
{
  if (offlineReadingsBufferedCount >= MAX_BUFFERED_READINGS)
  {
    Serial.println("[BUFFER] Local storage is full. Discarding new reading.");
    return;
  }
  preferences.begin("readings", false);
  String key = "reading_" + String(offlineReadingsBufferedCount);
  // Store in a simple, compact format for efficiency
  String payload = String(irState) + "," + String(waterState) + "," + String(weight);
  preferences.putString(key.c_str(), payload);
  offlineReadingsBufferedCount++;
  preferences.putInt("count", offlineReadingsBufferedCount);
  preferences.end();
  Serial.println("[BUFFER] Stored reading locally. Total buffered: " + String(offlineReadingsBufferedCount));
}

/**
 * @brief Reads the count of buffered readings from NVS at startup.
 */
void loadOfflineReadingCount()
{
  preferences.begin("readings", true);
  offlineReadingsBufferedCount = preferences.getInt("count", 0);
  preferences.end();
  Serial.println("[INIT] Found " + String(offlineReadingsBufferedCount) + " buffered readings.");
}

// =================================================================================================
//                                     SECTION 10: TIME MANAGEMENT
// =================================================================================================
/**
 * @brief Initializes the time system. Loads saved time from NVS and sets the timezone.
 */
void initializeTime()
{
  // --- Load the last synchronized time from NVS ---
  preferences.begin("time", true);
  lastNtpSyncMillis = preferences.getULong("lastSyncMillis", 0);
  lastNtpEpochTime = preferences.getLong("lastNTPTime", 0);
  preferences.end();

  if (lastNtpEpochTime > 0)
  {
    Serial.println("[TIME] Restored time from NVS.");
  }
  else
  {
    Serial.println("[TIME] No saved time found in NVS.");
  }

  // --- Set Timezone to Egypt (EET/EEST) ---
  // This is crucial for localtime_r() to work correctly with daylight saving.
  configTime(0, 0, "pool.ntp.org");
  setenv("TZ", "EET-2EEST,M4.5.5/0,M10.5.4/24", 1);
  tzset();
  Serial.println("[TIME] Timezone set to Egypt (EET/EEST).");
}

/**
 * @brief Forces an update from the NTP server and saves the new time to NVS.
 */
void synchronizeNTP()
{
  if (WiFi.status() == WL_CONNECTED)
  {
    ntpTimeClient.update();
    lastNtpEpochTime = ntpTimeClient.getEpochTime();
    lastNtpSyncMillis = millis();

    preferences.begin("time", false);
    preferences.putULong("lastSyncMillis", lastNtpSyncMillis);
    preferences.putLong("lastNTPTime", lastNtpEpochTime);
    preferences.end();

    Serial.println("[TIME] NTP time synchronized and saved to NVS.");
  }
  else
  {
    Serial.println("[TIME] Cannot sync NTP, no WiFi connection.");
  }
}

/**
 * @brief Gets the current time as a Unix epoch timestamp.
 * @return The current epoch time, or 0 if time has not been synchronized.
 * @details Provides a resilient way to get the current time. If online, it attempts a
 * fresh NTP sync. If the sync fails or the device is offline, it calculates
 * the time based on the last successful sync and the device's uptime (millis()).
 * This prevents time from becoming invalid during brief network interruptions.
 */
time_t getCurrentEpochTime()
{
  // Case 1: Device is connected to WiFi. Attempt to get the freshest time.
  if (WiFi.status() == WL_CONNECTED)
  {
    // Attempt to update the time from the NTP server.
    if (ntpTimeClient.update())
    {
      // If successful, refresh our local time anchor points. This is crucial
      // to prevent drift and ensures our offline calculations are accurate.
      lastNtpEpochTime = ntpTimeClient.getEpochTime();
      lastNtpSyncMillis = millis();
      return lastNtpEpochTime; // Return the fresh, accurate time.
    }
    // If the NTP update fails (e.g., UDP packet loss), fall back to calculation.
    else
    {
      unsigned long elapsedSeconds = (millis() - lastNtpSyncMillis) / 1000;
      return lastNtpEpochTime + elapsedSeconds;
    }
  }
  // Case 2: Device is offline, but we have a valid time saved from a previous sync.
  else if (lastNtpEpochTime > 0)
  {
    // Calculate the current time by adding the elapsed device uptime to our last anchor.
    unsigned long elapsedSeconds = (millis() - lastNtpSyncMillis) / 1000;
    return lastNtpEpochTime + elapsedSeconds;
  }
  // Case 3: Device is offline and has never successfully synced the time.
  else
  {
    return 0; // Return 0 to indicate that the time is unknown.
  }
}

/**
 * @brief Formats the current time into a "YYYY-MM-DD HH:MM" string.
 * @return A formatted string representation of the current time, or "Offline" if unavailable.
 */
String getFormattedDateTimeString()
{
  time_t epochTime = getCurrentEpochTime();
  if (epochTime == 0)
  {
    return "Time Unsynced";
  }
  struct tm timeinfo;
  gmtime_r(&epochTime, &timeinfo); // Using gmtime for a consistent UTC base
  char buffer[30];
  strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M", &timeinfo);
  return String(buffer);
}

// =================================================================================================
//                                     SECTION 11: HARDWARE CONTROL & UTILITIES
// =================================================================================================
/**
 * @brief Initiates or stops the motor control state machine.
 * @param state "open" to start oscillation, "close" to stop.
 */
void controlDispenserMotor(const char *state)
{
  Serial.print("[MOTOR] Action requested: ");
  Serial.println(state);

  if (strcmp(state, "open") == 0 && currentMotorState == MOTOR_IDLE)
  {
    // Start the oscillation by moving to the first position
    dispenserServo.write(ANGLE_LEFT);
    motorStateChangeTimestamp = millis();
    currentMotorState = MOTOR_DISPENSING_TOWARD_RIGHT; // Set state to start the loop
  }
  else if (strcmp(state, "close") == 0)
  {
    // Set the state to closing, which will be handled by the state machine
    currentMotorState = MOTOR_CLOSING;
  }
}

/**
 * @brief Updates the LCD screen only if the content of the lines has changed.
 * @param line1 The string to display on the first line.
 * @param line2 The string to display on the second line.
 */
void updateLcdScreen(const String &line1, const String &line2)
{
  if (line1 != lastLcdLine1)
  {
    lcd.setCursor(0, 0);
    lcd.print(line1.substring(0, LCD_COLUMNS));
    for (int i = line1.length(); i < LCD_COLUMNS; i++)
      lcd.print(" ");
    lastLcdLine1 = line1;
  }
  if (line2 != lastLcdLine2)
  {
    lcd.setCursor(0, 1);
    lcd.print(line2.substring(0, LCD_COLUMNS));
    for (int i = line2.length(); i < LCD_COLUMNS; i++)
      lcd.print(" ");
    lastLcdLine2 = line2;
  }
}

int readBowlWeight()
{
  return getPositiveWeight(10);
}

void tareBowlScale()
{
  scale.tare(20);
  Serial.println("[SCALE] Scale has been tared.");
}

/**
 * @brief Sets a flag to request the buzzer pattern to start.
 */
void triggerBuzzer()
{
  isBuzzerPatternRequested = true;
}
/**
 * @brief Reads the scale, rounds the value, and ensures it's never negative.
 */
int getPositiveWeight(int samples = 10)
{
  int weight = round(scale.get_units(samples));
  if (weight < 0)
  {
    return 0;
  }
  return weight;
}

/**
 * @brief Checks for a press on the external tare button to zero the scale.
 */
void handleTareButton()
{
  if (digitalRead(TARE_BUTTON_PIN) == HIGH)
  {
    if (millis() - lastTareButtonPress > 1000)
    {
      Serial.println("[TARE] External button pressed. Taring the scale...");
      tareBowlScale();
      stableWeight = getPositiveWeight(30);
      lastPublishedWeight = stableWeight;
      updateLcdScreen("Scale Tared", "Weight: " + String(stableWeight) + "g");
      lastLcdUpdateTimestamp = millis();
      lastTareButtonPress = millis();
    }
  }
}

/**
 * @brief Handles automatic taring (zeroing) of the scale to combat drift.
 */
void handleAutoTare()
{
  if (isWeightStable)
  {
    if (abs(stableWeight) < AUTO_TARE_THRESHOLD)
    {
      if (!isPotentiallyEmpty)
      {
        isPotentiallyEmpty = true;
        nearZeroSince = millis();
      }
      if (millis() - nearZeroSince >= AUTO_TARE_DURATION)
      {
        Serial.println("\n[AUTO-TARE] Correcting drift...");
        tareBowlScale();
        stableWeight = getPositiveWeight(30);
        lastPublishedWeight = stableWeight;
        isPotentiallyEmpty = false;
      }
    }
    else
    {
      isPotentiallyEmpty = false;
    }
  }
  else
  {
    isPotentiallyEmpty = false;
  }
}
// =================================================================================================
//                                     SECTION 12: SCHEDULE & PAYLOAD HELPERS
// =================================================================================================
/**
 * @brief Parses a JSON string containing a schedule and updates the global schedule array.
 * @details This modified version preserves the execution state (lastExecutionDay) for
 * schedule entries that have the same time, preventing duplicate feedings
 * when the schedule is refreshed.
 * @param jsonPayload The JSON string to parse.
 */
void parseScheduleFromJson(const String &jsonPayload)
{
  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, jsonPayload);
  FeedingTime newSchedule[MAX_SCHEDULED_FEEDS];
  int newScheduleCount = 0;
  JsonArray array = doc["schedule"];

  for (JsonObject feed : array)
  {
    if (newScheduleCount >= MAX_SCHEDULED_FEEDS)
      break;

    if (!feed.containsKey("amount") || !feed.containsKey("time"))
      continue;
    if (!feed["amount"].is<int>() || !feed["time"].is<String>())
      continue;

    int grams = feed["amount"];
    const char *timestamp = feed["time"];
    int hour = -1, minute = -1;
    sscanf(timestamp, "%d:%d", &hour, &minute);

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || grams <= 0)
      continue;

    newSchedule[newScheduleCount] = {hour, minute, grams, -1};
    newScheduleCount++;
  }

  for (int i = 0; i < newScheduleCount; i++)
  {
    for (int j = 0; j < activeScheduleCount; j++)
    {
      if (newSchedule[i].hour == feedingSchedule[j].hour && newSchedule[i].minute == feedingSchedule[j].minute)
      {
        newSchedule[i].lastExecutionDay = feedingSchedule[j].lastExecutionDay;
        break;
      }
    }
  }

  activeScheduleCount = newScheduleCount;
  for (int i = 0; i < activeScheduleCount; i++)
  {
    feedingSchedule[i] = newSchedule[i];
  }

  saveScheduleToNVS();
}

/**
 * @brief Creates a JSON-formatted string for status updates.
 * @param irState The current state of the IR sensor.
 * @param waterState The current state of the water sensor.
 * @param weight The current weight reading.
 * @return A JSON string.
 */
String createStatusJson(int irState, int waterState, int weight)
{
  JsonDocument doc;
  JsonObject status = doc.to<JsonObject>();

  status["food_weighted"] = (int)weight;
  status["water_level"] = waterState ? "high" : "low";
  status["main_stock"] = irState ? "high" : "low"; // Assuming IR 'high' means full

  String payload;
  serializeJson(doc, payload);
  return payload;
}