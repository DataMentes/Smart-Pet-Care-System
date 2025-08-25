// lib/core/api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../features/home/domain/models/pet_device.dart';
import '../features/device_control/domain/models/feeding_schedule.dart';
import '../features/history/domain/models/history_data.dart';

class ApiService {
  // ✅ تأكد دائمًا من أن هذا هو الـ IP الصحيح لجهازك
  final String _baseUrl = 'http://192.168.1.8:5000';

  Future<void> saveToken(String rawSessionData) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final session = jsonDecode(rawSessionData);
      await prefs.setString('authToken', session['access_token']);
    } catch (e) {
      debugPrint("Could not parse session data: $e");
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  // --- دوال المصادقة (بالمسارات الصحيحة) ---
  Future<http.Response> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fcm_token': 'some_placeholder_fcm_token',
      }),
    );
  }

  Future<http.Response> passwordResetRequest(String email) async {
    final url = Uri.parse(
      '$_baseUrl/auth/password-reset/request-otp',
    ); // ✅  تم تصحيح المسار
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  Future<http.Response> passwordResetVerify(String email, String otp) async {
    final url = Uri.parse(
      '$_baseUrl/auth/password-reset/verify-otp',
    ); // ✅  تم تصحيح المسار
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
  }

  Future<http.Response> passwordResetConfirm(
    String email,
    String otp,
    String newPassword,
  ) async {
    final url = Uri.parse(
      '$_baseUrl/auth/password-reset/confirm',
    ); // ✅  تم تصحيح المسار
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );
  }

  // --- دوال الشاشة الرئيسية (بالمسارات الصحيحة) ---
  Future<List<PetDevice>> getAllDeviceStatuses() async {
    final token = await getToken();
    final url = Uri.parse(
      '$_baseUrl/api/devices/all-statuses',
    ); // ✅  تم تصحيح المسار
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => PetDevice.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load device statuses');
    }
  }

  Future<http.Response> addDevice(String deviceId) async {
    final token = await getToken();
    final url = Uri.parse(
      '$_baseUrl/api/devices/register',
    ); // ✅  تم تصحيح المسار
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'device_id': deviceId}),
    );
  }

  // --- دوال شاشة التحكم ---
  Future<List<FeedingSchedule>> getSchedules(String deviceId) async {
    final token = await getToken();
    final url = Uri.parse('$_baseUrl/api/devices/$deviceId/schedule');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> scheduleData = data['schedule'] ?? [];
      return scheduleData
          .map((json) => FeedingSchedule.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load schedules');
    }
  }

  Future<http.Response> updateDeviceSchedule(
    String deviceId,
    List<FeedingSchedule> scheduleList,
  ) async {
    final token = await getToken();
    final url = Uri.parse('$_baseUrl/api/devices/$deviceId/schedule');
    final scheduleJson = scheduleList.map((s) => s.toJson()).toList();
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'schedule': scheduleJson}),
    );
  }

  Future<http.Response> feedNow(String deviceId, int amount) async {
    final topic = 'petfeeder/devices/$deviceId/feed_now';
    final payload = jsonEncode({'amount_grams': amount});
    // هذه الدالة يفترض أن تتواصل مع MQTT مباشرة أو عبر API
    // للتوافق مع كودك، سنفترض وجود API endpoint لها
    final token = await getToken();
    final url = Uri.parse(
      '$_baseUrl/api/devices/$deviceId/feed',
    ); // افترضنا وجود هذا المسار
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amountGrams': amount}),
    );
  }

  // --- دوال شاشة السجل ---
  Future<HistoryData> getHistoryFullReport(
    String deviceId,
    DateTimeRange dateRange,
    String period,
  ) async {
    final token = await getToken();
    final url = Uri.parse('$_baseUrl/api/devices/$deviceId/full-report')
        .replace(
          queryParameters: {
            'period': period, // weekly or monthly
          },
        );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      // الـ Backend يرسل chart_data مباشرة، سنقوم بمعالجته
      final rawData = jsonDecode(response.body);
      return HistoryData.fromFullReportJson(rawData);
    } else {
      throw Exception('Failed to load history data');
    }
  }

  Future<http.Response> signupRequestOtp(String email) async {
    final url = Uri.parse('$_baseUrl/auth/signup/request-otp');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  // دالة للتحقق من الكود وإنشاء الحساب
  Future<http.Response> signupVerify(Map<String, String> signupData) async {
    final url = Uri.parse('$_baseUrl/auth/signup/verify');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(signupData),
    );
  }
}
