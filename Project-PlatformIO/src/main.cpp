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
//                                     PIN DEFINITIONS
// =================================================================================================
#define SERVO_PIN 4
#define IR_PIN 16
#define WATER_SENSOR 35
#define LED_PIN 26
#define HX711_DT 32
#define HX711_SCK 33
#define WIFI_BUTTON_PIN 12
#define BUZZER_PIN 14

// =================================================================================================
//                                     CONFIGURATION CONSTANTS
// =================================================================================================
// ---------- LCD ----------
#define LCD_ADDRESS 0x27
#define LCD_COLUMNS 16
#define LCD_ROWS 2

// ---------- Servo ----------
#define SERVO_OPEN_ANGLE 90
#define SERVO_CLOSE_ANGLE 0
#define SERVO_NEUTRAL_ANGLE 0

// ---------- Scale & Dispensing ----------
const float CALIBRATION_FACTOR = -7050.0f;
const int DISPENSE_TOLERANCE_GRAMS = 2;
const long DISPENSE_TIMEOUT_MS = 20000;
const float SIMULATED_GRAMS_PER_SECOND = 30.0f;

// ---------- Sensors ----------
const int WATER_SENSOR_THRESHOLD = 1000;
const int WEIGHT_CHANGE_THRESHOLD = 5;

// ---------- Timing & Intervals (in milliseconds) ----------
const long MQTT_RECONNECT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const long WIFI_RECONNECT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const long LCD_UPDATE_INTERVAL_MS = 500;
const long SENSOR_PUBLISH_COOLDOWN_MS = 3 * 60 * 1000; // 3 minutes

// =================================================================================================
//                                     HARDWARE OBJECTS
// =================================================================================================
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLUMNS, LCD_ROWS);
Servo servo;
// HX711 scale; // Uncomment if using a real HX711

// =================================================================================================
//                                     NETWORK CONFIGURATION
// =================================================================================================
// ---------- MQTT ----------
const char *MQTT_HOST = "b8fde1f028ba4c73969c9d8905059c14.s1.eu.hivemq.cloud";
const int MQTT_PORT = 8883;
const char *MQTT_USER = "Smart-Pet-Care-System";
const char *MQTT_PASS = "Smart_care_pet_system_000";

char MQTT_CLIENT_ID[18];
char TOPIC_SCHEDULE[64];
char TOPIC_STATUS[64];

WiFiClientSecure espClient;
PubSubClient mqtt(espClient);
WiFiManager wm;

// ---------- NTP (Time) ----------
WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org");

// =================================================================================================
//                                     GLOBAL VARIABLES & STRUCTS
// =================================================================================================
struct Feeding
{
    int hour;
    int minute;
    int grams;
    int lastRunDay;
};
#define MAX_FEEDS 8
Feeding scheduleArr[MAX_FEEDS];
int scheduleCount = 0;

String last_line1 = "";
String last_line2 = "";

byte arrowUp[8] = {0b00100, 0b01110, 0b10101, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000};
byte arrowDown[8] = {0b00100, 0b00100, 0b00100, 0b00100, 0b10101, 0b01110, 0b00100, 0b00000};

Preferences preferences;

unsigned long lastMqttReconnectAttempt = 0;
unsigned long lastWifiReconnectAttempt = 0;
bool isDispensing = false;
unsigned long dispenseStartTime = 0;
unsigned long lastLcdUpdateTime = 0;
unsigned long lastWeightIncrementTime = 0;
int dispenseTargetGrams = 0;
int lastDisplayedWeight = -1;
unsigned long lastSyncMillis = 0;
time_t lastNTPTime = 0;
int lastIR = -1;
int lastWater = -1;
float lastWeight = -1;
unsigned long lastSensorPublishTime = 0;
unsigned long lastPeriodicSync = 0;
unsigned long buttonPressStartTime = 0;
bool buttonIsBeingPressed = false;
const unsigned long SYNC_INTERVAL_MS = 12UL * 60UL * 60UL * 1000UL;
unsigned long buzzPreviousMillis = 0;
int buzzState = LOW;
int buzzCount = 0;
bool buzzActive = false;
float simulatedWeight = 0.0;
bool buzzRequested = false;

int readingsBufferCount = 0;
const int MAX_BUFFERED_READINGS = 50;

// =================================================================================================
//                                     FORWARD DECLARATIONS
// =================================================================================================
void mqttPublishStatus(const String &msg);
String createStatusPayload(int ir, int water, float weight);
void storeReadingLocally(int ir, int water, float weight);
String getFormattedDateTime();

// =================================================================================================
//                                     SCHEDULE PERSISTENCE (No Changes)
// =================================================================================================
void saveSchedule()
{
    preferences.begin("pet-feeder", false);
    JsonDocument doc;
    JsonArray array = doc.to<JsonArray>();
    for (int i = 0; i < scheduleCount; i++)
    {
        JsonObject feed = array.add<JsonObject>();
        feed["device_id"] = MQTT_CLIENT_ID;
        feed["food_weighted"] = scheduleArr[i].grams;
        char timeBuffer[6];
        snprintf(timeBuffer, sizeof(timeBuffer), "%02d:%02d", scheduleArr[i].hour, scheduleArr[i].minute);
        feed["timestamp"] = timeBuffer;
    }
    String scheduleJson;
    serializeJson(doc, scheduleJson);
    preferences.putString("schedule", scheduleJson);
    preferences.end();
    Serial.println("[PREFS] Schedule saved.");
}

void loadSchedule()
{
    preferences.begin("pet-feeder", true);
    String scheduleJson = preferences.getString("schedule", "[]");
    preferences.end();
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, scheduleJson);
    if (err)
    {
        Serial.println("[PREFS] Failed to parse saved schedule.");
        scheduleCount = 0;
        return;
    }
    JsonArray array = doc.as<JsonArray>();
    scheduleCount = 0;
    for (JsonObject feed : array)
    {
        if (scheduleCount >= MAX_FEEDS)
            break;
        if (!feed.containsKey("food_weighted") || !feed.containsKey("timestamp") || !feed["food_weighted"].is<int>() || !feed["timestamp"].is<String>())
            continue;
        int g = feed["food_weighted"];
        const char *timestamp = feed["timestamp"];
        int h = -1, m = -1;
        sscanf(timestamp, "%d:%d", &h, &m);
        if (h < 0 || h > 23 || m < 0 || m > 59 || g <= 0)
            continue;
        scheduleArr[scheduleCount] = {h, m, g, -1};
        scheduleCount++;
    }
    Serial.print("[PREFS] Schedule loaded. Items: ");
    Serial.println(scheduleCount);
}

// =================================================================================================
//                                     HELPER FUNCTIONS (No Changes)
// =================================================================================================
void lcdPrintIfChanged(const String &l1, const String &l2)
{
    if (l1 != last_line1)
    {
        lcd.setCursor(0, 0);
        lcd.print(l1.substring(0, LCD_COLUMNS));
        for (int i = l1.length(); i < LCD_COLUMNS; i++)
            lcd.print(" ");
        last_line1 = l1;
    }
    if (l2 != last_line2)
    {
        lcd.setCursor(0, 1);
        lcd.print(l2.substring(0, LCD_COLUMNS));
        for (int i = l2.length(); i < LCD_COLUMNS; i++)
            lcd.print(" ");
        last_line2 = l2;
    }
}

void motor(const char *state)
{
    Serial.print("[MOTOR] Action: ");
    Serial.println(state);
    if (strcmp(state, "open") == 0)
        servo.write(SERVO_OPEN_ANGLE);
    else if (strcmp(state, "close") == 0)
        servo.write(SERVO_CLOSE_ANGLE);
}

void syncTimeAndSave()
{
    if (WiFi.status() == WL_CONNECTED)
    {
        timeClient.update();
        lastNTPTime = timeClient.getEpochTime();
        lastSyncMillis = millis();

        preferences.begin("time", false);
        preferences.putULong("lastSyncMillis", lastSyncMillis);
        preferences.putLong("lastNTPTime", lastNTPTime);
        preferences.end();

        Serial.println("[TIME] Synced & saved.");
    }
}

void loadSavedTime()
{
    preferences.begin("time", true);
    lastSyncMillis = preferences.getULong("lastSyncMillis", 0);
    lastNTPTime = preferences.getLong("lastNTPTime", 0);
    preferences.end();

    if (lastNTPTime > 0)
    {
        Serial.println("[TIME] Restored saved time.");
    }
    else
    {
        Serial.println("[TIME] No saved time found.");
    }
}

time_t getCurrentTime()
{
    if (WiFi.status() == WL_CONNECTED)
    {
        timeClient.update();
        return timeClient.getEpochTime();
    }
    else if (lastNTPTime > 0)
    {
        unsigned long elapsed = (millis() - lastSyncMillis) / 1000;
        return lastNTPTime + elapsed;
    }
    else
    {
        return 0;
    }
}

void buzz3times()
{
    // لو مش شغال حالياً: ابدأ
    if (!buzzActive)
    {
        buzzActive = true;
        buzzCount = 0;
        buzzState = HIGH;
        digitalWrite(BUZZER_PIN, buzzState);
        buzzPreviousMillis = millis();
        return;
    }

    unsigned long currentMillis = millis();
    if (currentMillis - buzzPreviousMillis >= 500)
    { // كل 0.5 ثانية
        buzzPreviousMillis = currentMillis;
        buzzState = !buzzState;
        digitalWrite(BUZZER_PIN, buzzState);

        // كل مرة يطفي نعد ضربة
        if (buzzState == LOW)
        {
            buzzCount++;
            if (buzzCount >= 3)
            {
                buzzActive = false;
                buzzRequested = false;         // ← مهم جداً عشان يقفل الطلب
                digitalWrite(BUZZER_PIN, LOW); // تأكيد إيقاف
            }
        }
    }
}

// =================================================================================================
//                                     SCALE & DISPENSING (No Changes)
// =================================================================================================
float readWeightOnce()
{
    return simulatedWeight;
}
void tareScale()
{
    simulatedWeight = 0.0;
    Serial.println("[SCALE] Tared.");
}

void startDispensing(int targetGrams)
{
    if (isDispensing)
    {
        Serial.println("[WARN] Already dispensing.");
        return;
    }

    if (WiFi.status() == WL_CONNECTED)
    {
        String startMsg = createStatusPayload(lastIR, lastWater, readWeightOnce());
        mqttPublishStatus(startMsg);
    }

    tareScale();
    isDispensing = true;
    dispenseTargetGrams = targetGrams;
    dispenseStartTime = millis();
    lastWeightIncrementTime = millis();
    lastDisplayedWeight = -1;
    motor("open");
    buzzRequested = true;
}

void handleDispensing()
{
    if (!isDispensing)
        return;

    unsigned long now = millis();
    if (now > lastWeightIncrementTime)
    {
        simulatedWeight += (now - lastWeightIncrementTime) / 1000.0f * SIMULATED_GRAMS_PER_SECOND;
        lastWeightIncrementTime = now;
    }

    float currentWeight = readWeightOnce();
    bool timeout = (now - dispenseStartTime > DISPENSE_TIMEOUT_MS);
    bool success = (currentWeight >= dispenseTargetGrams);

    if (now - lastLcdUpdateTime >= LCD_UPDATE_INTERVAL_MS)
    {
        lcdPrintIfChanged("Feeding...", "Weight: " + String((int)currentWeight) + "g");
        lastLcdUpdateTime = now;
    }

    if (timeout || success)
    {
        motor("close");
        isDispensing = false;
    }
}

// =================================================================================================
//                                     NEW NETWORK & DATA HANDLING
// =================================================================================================
void startConfigurationPortal()
{
    Serial.println("Configuration portal requested.");
    lcdPrintIfChanged("WiFi Setup Mode", "Connect to AP...");

    wm.setConfigPortalTimeout(180); // 3-minute timeout
    if (wm.startConfigPortal("Smart_Pet_Care_System_Config"))
    {
        Serial.println("WiFi configured successfully! Rebooting...");
    }
    else
    {
        Serial.println("Configuration timed out. Rebooting...");
    }

    delay(2000);
    ESP.restart();
}

void handleBackgroundWiFi()
{
    if (WiFi.status() == WL_CONNECTED)
    {
        static bool firstSyncDone = false;

        if (!firstSyncDone)
        {
            configTime(0, 0, "pool.ntp.org");
            setenv("TZ", "EET-2EEST,M4.5.5/0,M10.5.4/24", 1);
            tzset();

            Serial.println("[TIME] Timezone set to Egypt (EET/EEST).");

            syncTimeAndSave();
            firstSyncDone = true;
            lastPeriodicSync = millis();
        }

        if (millis() - lastPeriodicSync > SYNC_INTERVAL_MS)
        {
            syncTimeAndSave();
            lastPeriodicSync = millis();
        }
        return;
    }

    if (millis() - lastWifiReconnectAttempt > WIFI_RECONNECT_INTERVAL_MS)
    {
        Serial.println("Attempting to connect to last known WiFi in the background...");
        WiFi.begin();
        lastWifiReconnectAttempt = millis();
    }
}

void mqttPublishStatus(const String &msg)
{
    if (mqtt.connected())
    {
        mqtt.publish(TOPIC_STATUS, msg.c_str(), false);
    }
    Serial.println("[STATUS] " + msg);
}

void onMqttMessage(char *topic, byte *payload, unsigned int length)
{
    String msg;
    msg.reserve(length + 1);
    for (unsigned int i = 0; i < length; i++)
        msg += (char)payload[i];
    Serial.println("[MQTT] msg on " + String(topic) + ": " + msg);

    if (String(topic) == TOPIC_SCHEDULE)
    {
        preferences.begin("pet-feeder", true);
        if (preferences.getString("schedule", "[]").equals(msg))
        {
            Serial.println("[MQTT] Schedule is identical to saved one.");
            preferences.end();
            return;
        }
        preferences.end();

        Serial.println("[MQTT] New schedule received. Updating...");
        JsonDocument doc;
        DeserializationError err = deserializeJson(doc, msg);
        if (err)
        {
            mqttPublishStatus("[error] JSON parse failed");
            return;
        }
        if (!doc.is<JsonArray>())
        {
            mqttPublishStatus("[error] schedule not an array");
            return;
        }

        scheduleCount = 0;
        JsonArray array = doc.as<JsonArray>();
        for (JsonObject feed : array)
        {
            if (scheduleCount >= MAX_FEEDS)
                break;
            if (!feed.containsKey("device_id") || !feed.containsKey("food_weighted") || !feed.containsKey("timestamp") || String(feed["device_id"].as<const char *>()) != String(MQTT_CLIENT_ID))
                continue;
            if (!feed["food_weighted"].is<int>() || !feed["timestamp"].is<String>())
                continue;
            int g = feed["food_weighted"];
            const char *timestamp = feed["timestamp"];
            int h = -1, m = -1;
            sscanf(timestamp, "%d:%d", &h, &m);
            if (h < 0 || h > 23 || m < 0 || m > 59 || g <= 0)
                continue;
            scheduleArr[scheduleCount] = {h, m, g, -1};
            scheduleCount++;
        }
        mqttPublishStatus(String("[ok] schedule updated, items=") + scheduleCount);
        saveSchedule();
    }
}

void ensureMqtt()
{
    if (mqtt.connected())
        return;

    if ((millis() - lastMqttReconnectAttempt > MQTT_RECONNECT_INTERVAL_MS) || (lastMqttReconnectAttempt == 0))
    {
        lastMqttReconnectAttempt = millis();
        Serial.print("MQTT: connecting...");
        if (mqtt.connect(MQTT_CLIENT_ID, MQTT_USER, MQTT_PASS))
        {
            Serial.println("connected");
            mqtt.subscribe(TOPIC_SCHEDULE);
            mqttPublishStatus("[ok] mqtt reconnected");
            timeClient.begin();
        }
        else
        {
            Serial.print("failed rc=");
            Serial.println(mqtt.state());
        }
    }
}

String getFormattedDateTime()
{
    if (WiFi.status() != WL_CONNECTED)
    {
        return "Offline";
    }
    timeClient.update();
    time_t epochTime = timeClient.getEpochTime();
    struct tm timeinfo;
    gmtime_r(&epochTime, &timeinfo);
    char buffer[30];
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M", &timeinfo);
    return String(buffer);
}

String createStatusPayload(int ir, int water, float weight)
{
    JsonDocument doc;
    JsonObject status = doc.to<JsonObject>();

    status["device_id"] = MQTT_CLIENT_ID;
    status["food_weighted"] = (int)weight;
    status["water_level"] = water ? "high" : "low";
    status["main_stock"] = ir ? "high" : "low";
    status["timestamp"] = getFormattedDateTime();

    String payload;
    serializeJson(doc, payload);
    return payload;
}

void storeReadingLocally(int ir, int water, float weight)
{
    if (readingsBufferCount >= MAX_BUFFERED_READINGS)
    {
        Serial.println("[BUFFER] Local storage is full.");
        return;
    }
    preferences.begin("readings", false);
    String key = "reading_" + String(readingsBufferCount);
    // Use a simpler offline payload
    String payload = String(ir) + "," + String(water) + "," + String(weight);
    preferences.putString(key.c_str(), payload);
    readingsBufferCount++;
    preferences.putInt("count", readingsBufferCount);
    preferences.end();
    Serial.println("[BUFFER] Stored reading locally. Total: " + String(readingsBufferCount));
}

void syncStoredReadings()
{
    if (readingsBufferCount == 0 || !mqtt.connected())
        return;

    Serial.println("[SYNC] Starting to sync " + String(readingsBufferCount) + " buffered readings...");
    preferences.begin("readings", false);

    bool all_success = true;
    for (int i = 0; i < readingsBufferCount; i++)
    {
        String key = "reading_" + String(i);
        String payload_simple = preferences.getString(key.c_str(), "");
        if (payload_simple != "")
        {
            int ir, water;
            float weight;
            sscanf(payload_simple.c_str(), "%d,%d,%f", &ir, &water, &weight);
            String payload_json = createStatusPayload(ir, water, weight);

            if (!mqtt.publish(TOPIC_STATUS, payload_json.c_str(), false))
            {
                Serial.println("[SYNC] Failed to publish reading " + String(i) + ". Stopping sync.");
                all_success = false;
                break;
            }
            Serial.println("[SYNC] Published reading " + String(i));
            delay(100);
        }
    }

    if (all_success)
    {
        Serial.println("[SYNC] All buffered readings sent successfully. Clearing buffer.");
        preferences.clear();
        readingsBufferCount = 0;
        preferences.putInt("count", 0);
    }

    preferences.end();
}

// =================================================================================================
//                                     CORE LOGIC (No Changes)
// =================================================================================================
void handleSensorsAndUI()
{
    if (isDispensing)
        return;

    if (millis() - lastLcdUpdateTime >= LCD_UPDATE_INTERVAL_MS)
    {
        int ir_state = !digitalRead(IR_PIN);
        int water_read = analogRead(WATER_SENSOR);
        int water_state = water_read > WATER_SENSOR_THRESHOLD ? 1 : 0;
        float currentWeight = readWeightOnce();

        String line1 = "Tank:" + String(ir_state ? char(1) : char(2)) + " Water:" + String(water_state ? char(1) : char(2));
        String line2 = "Weight: " + String((int)currentWeight) + "g";
        lcdPrintIfChanged(line1, line2);

        bool significantChange = (ir_state != lastIR || water_state != lastWater || abs(currentWeight - lastWeight) >= WEIGHT_CHANGE_THRESHOLD);
        bool cooldownOver = (millis() - lastSensorPublishTime > SENSOR_PUBLISH_COOLDOWN_MS);

        if (significantChange && cooldownOver)
        {
            lastIR = ir_state;
            lastWater = water_state;
            lastWeight = currentWeight;
            lastSensorPublishTime = millis();

            if (WiFi.status() == WL_CONNECTED)
            {
                String payload = createStatusPayload(ir_state, water_state, currentWeight);
                mqttPublishStatus(payload);
            }
            else
            {
                storeReadingLocally(ir_state, water_state, currentWeight);
            }
        }
        lastLcdUpdateTime = millis();
    }
}

void handleScheduleExecution()
{
    if (isDispensing)
        return;

    time_t now = getCurrentTime();
    if (now == 0)
        return;

    struct tm timeinfo;
    localtime_r(&now, &timeinfo);

    int currentHour = timeinfo.tm_hour;
    int currentMinute = timeinfo.tm_min;
    int dayNumber = now / 86400;

    for (int i = 0; i < scheduleCount; i++)
    {
        if (scheduleArr[i].hour == currentHour && scheduleArr[i].minute == currentMinute)
        {
            if (scheduleArr[i].lastRunDay != dayNumber)
            {
                scheduleArr[i].lastRunDay = dayNumber;
                startDispensing(scheduleArr[i].grams);
                break;
            }
        }
    }
}

// =================================================================================================
//                                     NEW SETUP & LOOP
// =================================================================================================
void setup()
{
    Serial.begin(115200);

    uint8_t baseMac[6];
    esp_read_mac(baseMac, ESP_MAC_WIFI_STA);
    sprintf(MQTT_CLIENT_ID, "%02X:%02X:%02X:%02X:%02X:%02X", baseMac[0], baseMac[1], baseMac[2], baseMac[3], baseMac[4], baseMac[5]);
    Serial.print("Device ID: ");
    Serial.println(MQTT_CLIENT_ID);

    sprintf(TOPIC_SCHEDULE, "petfeeder/%s/schedule", MQTT_CLIENT_ID);
    sprintf(TOPIC_STATUS, "petfeeder/%s/status", MQTT_CLIENT_ID);

    pinMode(LED_PIN, OUTPUT);
    pinMode(2, OUTPUT);
    pinMode(WIFI_BUTTON_PIN, INPUT_PULLUP);
    pinMode(IR_PIN, INPUT_PULLUP);
    pinMode(WATER_SENSOR, INPUT);
    pinMode(BUZZER_PIN, OUTPUT);

    digitalWrite(BUZZER_PIN, LOW);

    lcd.init();
    lcd.backlight();
    lcd.createChar(1, arrowUp);
    lcd.createChar(2, arrowDown);

    preferences.begin("readings", true);
    readingsBufferCount = preferences.getInt("count", 0);
    preferences.end();
    Serial.println("[INIT] Found " + String(readingsBufferCount) + " buffered readings.");

    loadSchedule();
    loadSavedTime();

    servo.attach(SERVO_PIN);
    servo.write(SERVO_NEUTRAL_ANGLE);

    espClient.setInsecure();
    mqtt.setServer(MQTT_HOST, MQTT_PORT);
    mqtt.setCallback(onMqttMessage);

    // WiFi.mode(WIFI_STA);
    // WiFi.disconnect();
    // lastWifiReconnectAttempt = millis();
    // Serial.println("System starting in offline mode.");

    WiFi.mode(WIFI_STA);
    Serial.println("System starting... Attempting initial background connection.");
    // This starts a non-blocking connection attempt immediately on boot
    // using any saved credentials.
    WiFi.begin();
    lastWifiReconnectAttempt = millis();
}
void loop()
{
    // --- Check for Configuration Request ---

    if (digitalRead(WIFI_BUTTON_PIN) == HIGH)
    {
        if (!buttonIsBeingPressed)
        {
            buttonPressStartTime = millis();
            buttonIsBeingPressed = true;
        }
    }
    else
    {
        if (buttonIsBeingPressed)
        {
            buttonIsBeingPressed = false;
        }
    }

    if (buttonIsBeingPressed && (millis() - buttonPressStartTime > 5000))
    {
        startConfigurationPortal();
    }

    // --- Normal Operation (Always Runs) ---

    // 1. Handle background WiFi connection and MQTT
    handleBackgroundWiFi();
    if (WiFi.status() == WL_CONNECTED)
    {
        ensureMqtt();
        mqtt.loop();
    }

    // 2. Run all main application logic
    handleSensorsAndUI();
    handleScheduleExecution();

    if (buzzRequested)
    {
        buzz3times();
    }
    handleDispensing();

    // 3. Sync data if we are online
    if (mqtt.connected())
    {
        syncStoredReadings();
    }
}