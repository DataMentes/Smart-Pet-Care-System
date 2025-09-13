// lib/core/api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../features/home/domain/models/pet_device.dart';
import '../features/device_control/domain/models/feeding_schedule.dart';
import '../features/history/domain/models/history_data.dart';

class ApiService {
  final String _baseUrl =
      'http://192.168.1.8:5000'; // replace with your backend URL

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

  Future<http.Response> login(
    String email,
    String password,
    String fcmToken,
  ) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'fcm_token': fcmToken,
      }),
    );
  }

  Future<http.Response> passwordResetRequest(String email) async {
    final url = Uri.parse(
      '$_baseUrl/auth/password-reset/request-otp',
    );
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
  }

  Future<http.Response> passwordResetVerify(String email, String otp) async {
    final url = Uri.parse(
      '$_baseUrl/auth/password-reset/verify-otp',
    );
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
    );
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

  Future<List<PetDevice>> getAllDeviceStatuses() async {
    final token = await getToken();
    final url = Uri.parse(
      '$_baseUrl/api/devices/all-statuses',
    );
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

  Future<http.Response> addDevice(String name, String id) async {
    final token = await getToken();
    final url = Uri.parse('$_baseUrl/api/devices/register');
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'device_name': name, 'device_id': id}),
    );
  }

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
      return [];
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
    final topic = 'petfeeder/devices/$deviceId/feed-now';
    final payload = jsonEncode({'amount_grams': amount});
    final token = await getToken();
    final url = Uri.parse(
      '$_baseUrl/api/devices/$deviceId/feed-now',
    );
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );
  }

  Future<HistoryData> getHistoryFullReport(
    String deviceId,
    DateTimeRange dateRange,
    String period,
  ) async {
    final token = await getToken();
    final url =
        Uri.parse('$_baseUrl/api/devices/$deviceId/full-report').replace(
      queryParameters: {
        'period': period,
      },
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
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

  Future<http.Response> signupVerify(Map<String, String> signupData) async {
    final url = Uri.parse('$_baseUrl/auth/signup/verify');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(signupData),
    );
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
  }
}
