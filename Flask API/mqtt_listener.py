import paho.mqtt.client as mqtt
import json
import os
from dotenv import load_dotenv
from supabase import create_client, Client
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, messaging

try:
    cred = credentials.Certificate("firebase-service-account.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized successfully.")
except Exception as e:
    print(f"Error initializing Firebase Admin SDK: {e}")

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

MQTT_BROKER = "b8fde1f028ba4c73969c9d8905059c14.s1.eu.hivemq.cloud"
MQTT_PORT = 8883
MQTT_TOPIC_STATUS = "petfeeder/devices/+/status"
MQTT_TOPIC_CONSUMPTION = "petfeeder/devices/+/petfoodconsumption"
MQTT_USER = "Smart-Pet-Care-System"
MQTT_PASS = "Smart_care_pet_system_000"


def send_push_notification(user_email, title, body):
    try:
        response = (
            supabase_admin.table("fcm_tokens")
            .select("fcm_token")
            .eq("email", user_email)
            .execute()
        )

        if not response.data:
            print(f"No FCM tokens found for user: {user_email}")
            return

        tokens = [item["fcm_token"] for item in response.data]

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            tokens=tokens,
        )

        response = messaging.send_each_for_multicast(message)
        print(
            f"Successfully sent multicast message to {response.success_count} devices for user {user_email}."
        )

    except Exception as e:
        print(f"Error sending push notification to {user_email}: {e}")


def get_user_email_for_device(device_id):
    try:
        response = (
            supabase_admin.table("authenticated_devices")
            .select("email")
            .eq("device_id", device_id)
            .single()
            .execute()
        )
        return response.data.get("email")
    except Exception as e:
        print(f"Could not find user for device {device_id}: {e}")
        return None


def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT Broker with result code {rc}")
    client.subscribe(MQTT_TOPIC_STATUS)
    print(f"Subscribed to topic: {MQTT_TOPIC_STATUS}")
    client.subscribe(MQTT_TOPIC_CONSUMPTION)
    print(f"Subscribed to topic: {MQTT_TOPIC_CONSUMPTION}")


def on_message(client, userdata, msg):
    print(f"Received message on topic {msg.topic}")

    topic_parts = msg.topic.split("/")
    device_id = topic_parts[2]
    endpoint = topic_parts[-1]

    try:
        data = json.loads(msg.payload.decode())

        if endpoint == "status":
            print(f"Processing status message for device {device_id}: {data}")
            readings = {
                "device_id": device_id,
                "food_weighted": data.get("food_weighted"),
                "water_level": data.get("water_level"),
                "main_stock": data.get("main_stock"),
            }
            supabase_admin.table("sensors_device").upsert(readings).execute()
            print(f"Status data for {device_id} upserted into Supabase.")
            device_name_data = (
                supabase_admin.table("authenticated_devices")
                .select("device_name")
                .eq("device_id", device_id)
                .execute()
            )
            device_name = device_name_data.data[0]["device_name"]
            user_email = get_user_email_for_device(device_id)
            if not user_email:
                return
            if data.get("water_level") == "low":
                send_push_notification(
                    user_email,
                    "Water Level Low!",
                    f"The water for {device_name} is running low. Please refill it.",
                )
            if data.get("main_stock") == "low":
                send_push_notification(
                    user_email,
                    "Food Stock Low!",
                    f"The main food stock for {device_name} is low.",
                )

        elif endpoint == "petfoodconsumption":
            print(f"Processing consumption message for device {device_id}: {data}")
            consumption_record = {
                "device_id": device_id,
                "grams": data.get("grams"),
                "timestamp": datetime.now().isoformat(),
            }
            supabase_admin.table("pet_food_consumption").insert(
                consumption_record
            ).execute()
            print(f"Consumption data for {device_id} inserted into Supabase.")

    except Exception as e:
        print(f"Error processing message from topic {msg.topic}: {e}")


if __name__ == "__main__":
    client = mqtt.Client()

    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        print("Connecting to MQTT Broker...")
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.loop_forever()
    except Exception as e:
        print(f"Failed to start MQTT listener: {e}")
