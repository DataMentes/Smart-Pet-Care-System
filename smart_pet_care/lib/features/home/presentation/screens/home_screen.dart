// lib/features/home/presentation/screens/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/api_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../domain/models/pet_device.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<PetDevice>> _devicesFuture;

  @override
  void initState() {
    super.initState();
    _devicesFuture = _apiService.getAllDeviceStatuses();
  }

  void _refreshDevices() {
    setState(() {
      _devicesFuture = _apiService.getAllDeviceStatuses();
    });
  }

  void _showAddDeviceDialog() {
    // ✅  التصحيح: سنستخدم controller واحد فقط
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅  التصحيح: حذف حقل اسم الجهاز لأنه غير مستخدم في الـ Backend
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Device ID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () async {
              final id = idController.text;
              if (id.isNotEmpty) {
                try {
                  final response = await _apiService.addDevice(id);
                  Navigator.of(ctx).pop();

                  if (response.statusCode == 201 && mounted) {
                    _refreshDevices();
                  } else if (mounted) {
                    final error = jsonDecode(response.body)['message'] ??
                        jsonDecode(response.body)['error'];
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $error')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add device: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              ThemeProvider.themeNotifier.value =
                  isDarkMode ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "How is your pet today?",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FutureBuilder<List<PetDevice>>(
                  future: _devicesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // ✅  التصحيح: التعامل مع الحالة الفارغة أولاً برسالة ترحيبية
                    if (snapshot.hasData && snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Welcome! No devices found.\nAdd your first device to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    // ✅  التصحيح: التعامل مع الخطأ برسالة أوضح
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load devices. Please try again.\nError: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final devices = snapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async => _refreshDevices(),
                      child: ListView(
                        children: [
                          ...devices
                              .map((device) => DeviceCard(device: device))
                              .toList(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Device'),
                  onPressed: _showAddDeviceDialog,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
