# 🐾 Smart Pet Care System

**An integrated IoT system to automate the feeding and remote monitoring of your pets, ensuring their well-being and your peace of mind.**

---

## 📜 Table of Contents
1.  [Abstract](#1-abstract)
2.  [Problem Statement](#2-problem-statement)
3.  [Key Features](#3-key-features)
4.  [System Architecture & Tech Stack](#4-system-architecture--tech-stack)
5.  [Getting Started](#5-getting-started)
6.  [API Endpoints Overview](#6-api-endpoints-overview)

---

## 1. Abstract
An integrated IoT-based system designed to automate the feeding and remote monitoring of pets. The project aims to provide pet owners with peace of mind by ensuring their pets receive proper and regular nutrition, even in their absence, while also providing valuable analytical data about their pets' eating habits.

## 2. Problem Statement
Many pet owners face difficulty in adhering to a fixed and regular feeding schedule due to busy work lives or travel. Manual feeding can lead to inconsistent meal portions and timings, which may cause long-term health issues for the pet, such as obesity or malnutrition. This also creates constant anxiety for the owner about their pet's well-being when they are away.

---

## 3. Key Features
The system is divided into two main components: the Smart Feeder Device and the Mobile Application.

### A. The Smart Feeder (Hardware)
* **Automated & Scheduled Food Dispensing:** Dispenses precisely measured food portions at user-defined times.
* **Real-time Sensor Monitoring:** Equipped with sensors to monitor the food level in the bowl, the main food stock, and the water tank level.

### B. The Mobile Application (Software)
* **Secure User Authentication:**
    * Full signup flow with two-step OTP email verification.
    * Secure login with persistent sessions.
    * Complete "Forgot Password" functionality with OTP verification.
* **Real-time Dashboard:**
    * A home screen that displays the live status of all connected devices (food stock, water level).
    * UI updates automatically in real-time when the device status changes, without needing a manual refresh.
* **Device Management:**
    * Ability to register new devices to the user's account using a unique Device ID.
* **Advanced Feeding Control:**
    * **Schedule Management:** An intuitive interface to create, edit, and delete multiple feeding schedules, specifying the time and quantity for each meal.
    * **Instant Feeding:** A feature to dispense a specified amount of food immediately with the press of a button.
* **Analytical Reports & History:**
    * Interactive charts displaying food consumption history.
    * Filter data by period (Daily, Weekly, Monthly) and custom date ranges.
    * Key statistics such as total consumption and daily average.
* **Real-time Notification System:**
    * Sends push notifications for critical events like low food stock or low water levels.
    * Sends a daily reminder to the user to change the pet's drinking water for freshness.



---

## 4. System Architecture & Tech Stack
The system relies on an integrated architecture:

1.  **Hardware Layer (The Device):**
    * **Microcontroller:** An **ESP32** device collects data from sensors and controls the motors.
    * **Protocol:** Communicates with the server via the **MQTT** protocol.

2.  **Backend Layer (The Server):**
    * **Framework:** An API built with **Flask (Python)**.
    * **Functionality:** Receives data from the device and the app, processes it, and communicates with the database.
    * **Real-time Services:** Includes a separate MQTT listener and a task scheduler for notifications.

3.  **Frontend Layer (The App):**
    * **Framework:** A cross-platform mobile application built with **Flutter (Dart)**.
    * **Functionality:** Provides the user interface for monitoring and control.

4.  **Database & Authentication:**
    * **Provider:** **Supabase** is used for the PostgreSQL database and user authentication management (GoTrue).

---

## 5. Getting Started
To set up and run this project locally, you will need to configure the Backend and the Frontend separately.

### Prerequisites
* Flutter SDK
* Python 3.x & Pip
* A Supabase Project
* A Firebase Project
* A SendGrid Account (for email OTP)

### Backend Setup
1.  Navigate to the `Flask API` directory.
2.  Create and activate a Python virtual environment: `python -m venv venv` and `source venv/bin/activate`.
3.  Install the required packages: `pip install -r requirements.txt`.
4.  Create a `.env` file and fill it with your keys (Supabase URL/Key, SendGrid API Key, etc.).
5.  Place your `firebase-service-account.json` file in the backend directory.
6.  Run the API server: `flask run`.
7.  In separate terminal windows, run the worker scripts: `python mqtt_listener.py` and `python scheduler.py`.

### Frontend (Flutter App) Setup
1.  Navigate to the `smart_pet_care` directory.
2.  Get dependencies: `flutter pub get`.
3.  Configure Firebase for your project: `flutterfire configure --platforms=android`.
4.  Download your `google-services.json` file from Firebase and place it in `android/app/`.
5.  Open `lib/core/api_service.dart` and update the `_baseUrl` variable with your local IP address.
6.  Connect a device and run the app: `flutter run`.

---

## 6. API Endpoints Overview

| Method & Endpoint                          | Description                               |
| ------------------------------------------ | ----------------------------------------- |
| **Authentication** |                                           |
| `POST /auth/signup/request-otp`            | Starts the registration process.          |
| `POST /auth/signup/verify`                 | Verifies OTP and creates the user.        |
| `POST /auth/login`                         | Logs in an existing user.                 |
| `POST /auth/password-reset/request-otp`    | Starts the password reset process.        |
| `POST /auth/password-reset/verify-otp`     | Verifies the password reset OTP.          |
| `POST /auth/password-reset/confirm`        | Sets the new password.                    |
| **Devices** |                                           |
| `GET /api/devices/all-statuses`            | Gets the latest status of all devices.    |
| `POST /api/devices/register`               | Registers a new device to the user.       |
| `GET /api/devices/<id>/schedule`           | Gets the schedule for a specific device.  |
| `POST /api/devices/<id>/schedule`          | Updates the entire schedule for a device. |
| `GET /api/devices/<id>/full-report`        | Gets analytical data for a device.        |
