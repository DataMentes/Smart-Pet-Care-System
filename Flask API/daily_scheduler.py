import schedule
import time
import os
from dotenv import load_dotenv
from supabase import create_client, Client
import firebase_admin
from firebase_admin import credentials, messaging

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

try:
    cred = credentials.Certificate("firebase-service-account.json")
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized for scheduler.")
except Exception as e:
    print(f"Error initializing Firebase Admin SDK for scheduler: {e}")

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


def send_push_notification(user_email, title, body):
    try:
        response = supabase_admin.table("fcm_tokens").select("fcm_token").eq("email", user_email).execute()

        if not response.data:
            print(f"No FCM tokens found for user: {user_email}")
            return

        tokens = [item['fcm_token'] for item in response.data]

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            tokens=tokens,
        )

        response = messaging.send_multicast(message)
        print(f"Successfully sent multicast message to {response.success_count} devices for user {user_email}.")

    except Exception as e:
        print(f"Error sending push notification to {user_email}: {e}")


def send_daily_water_reminder():
    print(f"Running daily water reminder job at {time.ctime()}...")
    try:
        response = supabase_admin.table("Users").select("email").execute()
        if response.data:
            for user in response.data:
                user_email = user.get("email")
                if user_email:
                    send_push_notification(
                        user_email,
                        "Daily Reminder",
                        "Don't forget to change and clean your pet's water today to keep them healthy!"
                    )
    except Exception as e:
        print(f"Error running daily job: {e}")


schedule.every().day.at("09:00").do(send_daily_water_reminder)
print("Scheduler started. Waiting for the scheduled time...")
while True:
    schedule.run_pending()
    time.sleep(60)