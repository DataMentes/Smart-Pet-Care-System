import schedule
import time
import os
import json
from dotenv import load_dotenv
from supabase import create_client, Client
import firebase_admin
from firebase_admin import credentials, messaging

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

try:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    cred_path = os.path.join(script_dir, "firebase-service-account.json")
    
    if not os.path.exists(cred_path):
        raise FileNotFoundError(f"Firebase credentials file not found at {cred_path}")

    cred = credentials.Certificate(cred_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized successfully.")

except Exception as e:
    print(f"CRITICAL: Error initializing Firebase Admin SDK: {e}")
    exit()

MQTT_BROKER = "b8fde1f028ba4c73969c9d8905059c14.s1.eu.hivemq.cloud"
MQTT_PORT = 8883
MQTT_USER = "Smart-Pet-Care-System"
MQTT_PASS = "Smart_care_pet_system_000"


def publish_mqtt_message(topic, payload):
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        client.username_pw_set(MQTT_USER, MQTT_PASS)
        client.tls_set()
        
        print(f"Connecting to MQTT to publish on {topic}...")
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        
        client.loop_start()
        
        json_payload = json.dumps(payload)
        result = client.publish(topic, json_payload)
        
        result.wait_for_publish()
        if result.is_published():
             print(f"Published to {topic}: {json_payload}")
        else:
            print(f"Failed to publish message to {topic}")

        client.loop_stop()
        client.disconnect()
        
    except Exception as e:
        print(f"An error occurred in publish_mqtt_message: {e}")

def send_notifications_in_batches(tokens, title, body):
    if not tokens:
        print("Token list is empty, no notifications to send.")
        return

    batch_size = 500
    token_chunks = [tokens[i:i + batch_size] for i in range(0, len(tokens), batch_size)]

    success_count = 0
    failure_count = 0

    for chunk in token_chunks:
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            tokens=chunk,
        )
        
        try:
            response = messaging.send_each_for_multicast(message)
            success_count += response.success_count
            failure_count += response.failure_count
        except Exception as e:
            failure_count += len(chunk)
            print(f"Error sending a batch of notifications: {e}")

    print(f"Batch sending finished. Total successful: {success_count}, Total failed: {failure_count}")

def send_daily_water_reminder():
    print(f"Running optimized daily water reminder job at {time.ctime()}...")
    try:
        response = supabase_admin.table("fcm_tokens").select("fcm_token").execute()
        
        if not response.data:
            print("No FCM tokens found in the database.")
            return

        all_tokens = [item['fcm_token'] for item in response.data if item.get('fcm_token')]
        
        send_notifications_in_batches(
            all_tokens,
            "Daily Reminder",
            "Don't forget to change and clean your pet's water today to keep them healthy!"
        )

    except Exception as e:
        print(f"A critical error occurred in the daily job: {e}")
        
        
schedule.every().day.at("09:00").do(send_daily_water_reminder)
print("Scheduler started. Waiting for the scheduled time...")
while True:
    schedule.run_pending()
    time.sleep(10)