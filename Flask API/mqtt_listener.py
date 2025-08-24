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

MQTT_BROKER  = "broker.hivemq.com"
MQTT_PORT = 1883
MQTT_TOPIC = "petfeeder/devices/+/status"


def send_push_notification(user_email, title, body):
    try:
        response = supabase_admin.table("Users").select("fcm_token").eq("email", user_email).single().execute()
        user_token = response.data.get("fcm_token")
        if not user_token:
            print(f"No FCM token found for user: {user_email}")
            return
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=user_token,
        )
        response = messaging.send(message)
        print('Successfully sent message:', response)
        print("="*30)
    except Exception as e:
        print(f"Error sending push notification to {user_email}: {e}")
        print("="*30)

def get_user_email_for_device(device_id):
    try:
        response = supabase_admin.table("authenticated_devices").select("email").eq("device_id", device_id).single().execute()
        return response.data.get("email")
    except Exception as e:
        print(f"Could not find user for device {device_id}: {e}")
        return None

def on_connect(client, userdata, flags, rc):
    print(f"Connected to MQTT Broker with result code {rc}")
    client.subscribe(MQTT_TOPIC)
    print(f"Subscribed to topic: {MQTT_TOPIC}")

def on_message(client, userdata, msg):
    try:
        print(f"Received message on topic {msg.topic}: {msg.payload.decode()}")
        device_id = msg.topic.split('/')[2]
        data = json.loads(msg.payload.decode())
        log_entry = {
            "device_id": device_id,
            "food_weighted": data.get("food_weighted"),
            "water_level": data.get("water_level"),
            "main_stock": data.get("main_stock"),
            "timestamp": datetime.now().isoformat()
        }
        supabase_admin.table("Sensors_device").insert(log_entry).execute()
        print(f"Data for {device_id} inserted into Supabase.")

        user_email = get_user_email_for_device(device_id)
        if not user_email:
            return
        if data.get("water_level") == "low":
            send_push_notification(user_email, 
                                   "Water Level Low!", 
                                   "The water in your pet feeder is running low. Please refill it.")
        if data.get("main_stock") == "low":
            send_push_notification(user_email, 
                                   "Food Stock Low!", 
                                   f"The main food stock for device {device_id} is low.")
    except Exception as e:
        print(f"Error processing message: {e}")

print("Starting MQTT Listener...")
client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message
client.connect(MQTT_BROKER, MQTT_PORT, 60)
client.loop_forever()