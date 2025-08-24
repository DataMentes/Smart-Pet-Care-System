import os
import json
import random
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from supabase import create_client, Client
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from dotenv import load_dotenv
import paho.mqtt.client as mqtt
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase_user: Client = create_client(SUPABASE_URL, SUPABASE_ANON_KEY)
supabase_admin: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883

app = Flask(__name__)

# --- Helper Functions ---

def publish_to_mqtt(topic, payload):
    try:
        client = mqtt.Client()
        client.connect(MQTT_BROKER, MQTT_PORT, 60)
        client.publish(topic, payloadو retain=True)
        client.disconnect()
        print(f"Published to {topic}: {payload}")
    except Exception as e:
        print(f"Failed to publish to MQTT: {e}")

def send_otp_email(recipient_email, otp_code):
    message = Mail(
        from_email=os.getenv('VERIFIED_SENDER_EMAIL'),
        to_emails=recipient_email,
        subject='Your Pet Feeder Verification Code',
        html_content=f"""
            <div style="font-family: Arial, sans-serif; text-align: center; color: #333;">
                <h2>Welcome to Pet Feeder!</h2>
                <p>Your verification code is:</p>
                <p style="font-size: 24px; font-weight: bold; letter-spacing: 5px; background-color: #f0f0f0; padding: 10px; border-radius: 5px;">
                    {otp_code}
                </p>
                <p>This code will expire in 10 minutes.</p>
            </div>
        """
    )
    try:
        sg = SendGridAPIClient(os.getenv('SENDGRID_API_KEY'))
        response = sg.send(message)
        print(f"Email sent to {recipient_email}, Status Code: {response.status_code}")
        return True
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

# --- Public & Status Routes ---

@app.route("/")
def welcome():
    return "Welcome to the Pet Feeder API"

@app.route("/status", methods=["GET"])
def api_status():
    db_status = {
        "status": "unhealthy",
        "details": "Connection could not be established."
    }
    
    try:
        supabase_admin.table("Users").select("id").limit(1).execute()
        
        db_status["status"] = "healthy"
        db_status["details"] = "Database connection is successful."
        
    except Exception as e:
        print(f"DATABASE HEALTH CHECK FAILED: {e}")
        db_status["details"] = str(e)

    status_data = {
        "api_status": "online",
        "timestamp": datetime.now().isoformat(),
        "database_connection": db_status
    }
    
    if db_status["status"] == "unhealthy":
        return jsonify(status_data), 503

    return jsonify(status_data), 200

# --- Authentication Routes ---

@app.route("/auth/signup/request-otp", methods=["POST"])
def signup_request_otp():
    try:
        data = request.get_json()
        email = data.get("email")
        if not email:
            return jsonify({"error": "Email is required"}), 400
        user_check = supabase_admin.table("Users").select("email").eq("email", email).execute()
        if user_check.data:
            return jsonify({"error": "Email already exists"}), 409
        otp_code = str(random.randint(100000, 999999))
        hashed_otp = generate_password_hash(otp_code)
        expires_at = (datetime.now() + timedelta(minutes=10)).isoformat()
        supabase_admin.table("otp_codes").upsert({
            "email": email,
            "code": hashed_otp,
            "expires_at": expires_at
        }).execute()
        send_otp_email(email, otp_code)
        return jsonify({"message": "A verification code has been sent to your email."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/auth/signup/verify", methods=["POST"])
def signup_verify():
    try:
        data = request.get_json()
        required_fields = ["email", "password", "first_name", "last_name", "otp", "fcm_token"]
        if not all(field in data for field in required_fields):
            return jsonify({"error": "Missing required fields"}), 400
        email = data["email"]
        otp_from_user = data["otp"]
        password = data["password"]
        fcm_token = data.get("fcm_token")
        otp_record_res = supabase_admin.table("otp_codes").select("*").eq("email", email).single().execute()
        otp_record = otp_record_res.data
        if not otp_record:
            return jsonify({"error": "Invalid email or no OTP request found"}), 400
        utc_now = datetime.now(datetime.now().astimezone().tzinfo)
        is_expired = datetime.fromisoformat(otp_record["expires_at"]) < utc_now
        is_correct = check_password_hash(otp_record["code"], otp_from_user)
        if is_expired: return jsonify({"error": "OTP has expired"}), 401
        if not is_correct: return jsonify({"error": "Invalid OTP"}), 401
        auth_response = supabase_user.auth.sign_up({"email": email, "password": password})
        new_user_id = auth_response.user.id
        profile_data = {
            "id": new_user_id,
            "email": email,
            "first_name": data.get("first_name"),
            "last_name": data.get("last_name"),
            "fcm_token": fcm_token
        }
        supabase_admin.table("Users").insert(profile_data).execute()
        supabase_admin.table("otp_codes").delete().eq("email", email).execute()
        return jsonify(auth_response.session.dict()), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/auth/login", methods=["POST"])
def login():
    try:
        data = request.get_json()
        if not data or "email" not in data or "password" not in data or "fcm_token" not in data:
            return jsonify({"error": "Email, password, and fcm_token are required"}), 400
        email = data["email"]
        password = data["password"]
        fcm_token = data["fcm_token"]
        auth_response = supabase_user.auth.sign_in_with_password({
            "email": email,
            "password": password
        })
        user_id = auth_response.user.id
        supabase_admin.table("Users").update({
            "fcm_token": fcm_token
        }).eq(
            "id", user_id
        ).execute()
        return jsonify(auth_response.session.dict()), 200
    
    except Exception as e:
        return jsonify({"error": "Invalid login credentials", "details": str(e)}), 401

@app.route("/auth/password-reset/request-otp", methods=["POST"])
def password_reset_request():
    try:
        data = request.get_json()
        email = data.get("email")
        if not email: return jsonify({"error": "Email is required"}), 400

        user_check = supabase_admin.table("Users").select("id").eq("email", email).single().execute()
        if not user_check.data:
            return jsonify({"message": "If an account with this email exists, a reset code has been sent."})

        otp_code = str(random.randint(100000, 999999))
        hashed_otp = generate_password_hash(otp_code)
        expires_at = (datetime.now() + timedelta(minutes=10)).isoformat()
        
        supabase_admin.table("otp_codes").upsert({"email": email, "code": hashed_otp, "expires_at": expires_at}).execute()
        send_otp_email(email, otp_code)
        return jsonify({"message": "If an account with this email exists, a reset code has been sent."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/auth/password-reset/verify-otp", methods=["POST"])
def password_reset_verify():
    try:
        data = request.get_json()
        email = data.get("email")
        otp_from_user = data.get("otp")
        if not email or not otp_from_user: return jsonify({"error": "Email and OTP are required"}), 400

        otp_record_res = supabase_admin.table("otp_codes").select("*").eq("email", email).single().execute()
        if not otp_record_res.data: return jsonify({"error": "Invalid OTP or request not found"}), 401

        otp_record = otp_record_res.data
        utc_now = datetime.now(datetime.now().astimezone().tzinfo)
        is_expired = datetime.fromisoformat(otp_record["expires_at"]) < utc_now
        is_correct = check_password_hash(otp_record["code"], otp_from_user)

        if is_expired or not is_correct: return jsonify({"error": "Invalid or expired OTP"}), 401
        
        return jsonify({"status": "success", "message": "OTP verified successfully. You can now set a new password."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/auth/password-reset/confirm", methods=["POST"])
def password_reset_confirm():
    try:
        data = request.get_json()
        required_fields = ["email", "otp", "new_password"]
        if not all(field in data for field in required_fields): return jsonify({"error": "Missing required fields"}), 400

        email = data["email"]
        otp_from_user = data["otp"]
        new_password = data["new_password"]

        otp_record_res = supabase_admin.table("otp_codes").select("*").eq("email", email).single().execute()
        if not otp_record_res.data: return jsonify({"error": "Invalid request. Please start over."}), 401
            
        otp_record = otp_record_res.data
        utc_now = datetime.now(datetime.now().astimezone().tzinfo)
        is_expired = datetime.fromisoformat(otp_record["expires_at"]) < utc_now
        is_correct = check_password_hash(otp_record["code"], otp_from_user)
        if is_expired or not is_correct: return jsonify({"error": "Invalid or expired OTP. Please start over."}), 401

        user_res = supabase_admin.table("Users").select("id").eq("email", email).single().execute()
        user_id = user_res.data["id"]

        supabase_admin.auth.admin.update_user_by_id(user_id, {"password": new_password})
        supabase_admin.table("otp_codes").delete().eq("email", email).execute()
        return jsonify({"message": "Password has been updated successfully. Please log in."})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- API Routes (Require Authentication) ---

@app.route("/api/devices", methods=["GET"])
def get_user_devices():
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: return jsonify({"error": "Invalid token"}), 401
        devices_response = supabase_admin.table("authenticated_devices").select("device_id").eq("email", user.email).execute()
        return jsonify(devices_response.data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/devices/register", methods=["POST"])
def register_new_device():
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: return jsonify({"error": "Invalid token"}), 401
        data = request.get_json()
        device_id = data.get("device_id")
        if not device_id: return jsonify({"error": "device_id is required"}), 400
        device_check = supabase_admin.table("Devices").select("device_id").eq("device_id", device_id).execute()
        if not device_check.data: return jsonify({"error": "Device ID not valid"}), 404
        auth_device_check = supabase_admin.table("authenticated_devices").select("device_id").eq("device_id", device_id).execute()
        if auth_device_check.data: return jsonify({"error": "Device already registered"}), 409
        link_data = {"device_id": device_id, "email": user.email}
        supabase_admin.table("authenticated_devices").insert(link_data).execute()
        return jsonify({"status": "success", "message": f"Device {device_id} registered successfully."}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/devices/all-statuses", methods=["GET"])
def get_all_statuses():
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: return jsonify({"error": "Invalid token"}), 401
        devices_list_res = supabase_admin.table("authenticated_devices").select("device_id").eq("email", user.email).execute()
        if not devices_list_res.data:
            return jsonify([])
        device_ids = [d['device_id'] for d in devices_list_res.data]
        all_statuses = []
        for device_id in device_ids:
            status_res = supabase_admin.table("Sensors_device").select("*").eq("device_id", device_id).order("timestamp", desc=True).limit(1).single().execute()
            if status_res.data:
                all_statuses.append(status_res.data)
        return jsonify(all_statuses)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/devices/<string:device_id>/full-report", methods=["GET"])
def get_device_full_report(device_id):
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: 
            return jsonify({"error": "Invalid token"}), 401
        
        ownership_check = supabase_admin.table("authenticated_devices").select("device_id").eq("device_id", device_id).eq("email", user.email).execute()
        if not ownership_check.data: 
            return jsonify({"error": "Forbidden"}), 403

        period = request.args.get("period", default="weekly", type=str)
        days_range = 30 if period == "monthly" else 7
        
        start_date = datetime.now() - timedelta(days=days_range)

        history_res = supabase_admin.table("Sensors_device").select(
            "timestamp, food_weighted"
        ).eq(
            "device_id", device_id
        ).gte(
            "timestamp", start_date.isoformat()
        ).order(
            "timestamp"
        ).execute()

        if not history_res.data:
            return jsonify({"error": "No data found for this period"}), 404

        food_data = [d['food_weighted'] for d in history_res.data if d.get('food_weighted') is not None]
        total_consumed = sum(food_data)
        days_with_data = len(set(d['timestamp'].split('T')[0] for d in history_res.data if d.get('food_weighted') is not None))
        average_daily = total_consumed / days_with_data if days_with_data > 0 else 0
        
        full_report = {
            "analytics": {
                "period": period,
                "total_consumed_grams": total_consumed,
                "average_daily_consumption_grams": round(average_daily, 2)
            },
            "chart_data": history_res.data 
        }
        
        return jsonify(full_report)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/devices/<string:device_id>/schedule", methods=["GET"])
def get_device_schedule(device_id):
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: return jsonify({"error": "Invalid token"}), 401
        
        ownership_check = supabase_admin.table("authenticated_devices").select("device_id").eq("device_id", device_id).eq("email", user.email).execute()
        if not ownership_check.data: return jsonify({"error": "Forbidden"}), 403

        schedule_data = supabase_admin.table("schedules").select(
            "feed_time, amount_grams"
        ).eq(
            "device_id", device_id
        ).execute().data
        
        return jsonify({"schedule": schedule_data})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/devices/<string:device_id>/schedule", methods=["POST"])
def update_device_schedule(device_id):
    try:
        jwt = request.headers.get("Authorization").split(" ")[1]
        user = supabase_user.auth.get_user(jwt).user
        if not user: return jsonify({"error": "Invalid or expired token"}), 401

        ownership_check = supabase_admin.table("authenticated_devices").select("device_id").eq("device_id", device_id).eq("email", user.email).execute()
        if not ownership_check.data: return jsonify({"error": "Forbidden: You do not own this device"}), 403

        data = request.get_json()
        new_schedule = data.get("schedule")
        if not isinstance(new_schedule, list): return jsonify({"error": "Request body must contain a 'schedule' list"}), 400

        supabase_admin.table("schedules").delete().eq("device_id", device_id).eq("email", user.email).execute()

        schedule_to_insert = []
        if new_schedule:
            for item in new_schedule:
                schedule_to_insert.append({
                    "device_id": device_id,
                    "email": user.email,
                    "feed_time": item.get("time"),
                    "amount_grams": item.get("amount")
                })

        if schedule_to_insert:
            supabase_admin.table("schedules").insert(schedule_to_insert).execute()
        
        topic = f"petfeeder/devices/{device_id}/schedule_update"
        payload = json.dumps({"schedule": new_schedule})
        publish_to_mqtt(topic, payload)
        
        return jsonify({"status": "success", "message": f"Schedule for device {device_id} has been updated and sent."})
    
    except Exception as e:
        return jsonify({"error": "An error occurred", "details": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)