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
        print(f"Successfully sent daily reminder to {user_email}")
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