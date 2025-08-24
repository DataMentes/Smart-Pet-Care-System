// lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../domain/models/pet_device.dart';
import '../widgets/device_card.dart';

// ✅  التصحيح: تحويلها إلى StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅  التصحيح: نقل قائمة الأجهزة إلى هنا لتكون جزءاً من الـ State
  final List<PetDevice> _devices = [
    PetDevice(
      id: 'SN-112233',
      name: 'Device 1',
      foodWeightGrams: 120,
      isFoodStockHigh: true,
      isWaterTankFull: true,
    ),
    PetDevice(
      id: 'SN-445566',
      name: 'Device 2',
      foodWeightGrams: 80,
      isFoodStockHigh: false,
      isWaterTankFull: false,
    ),
    PetDevice(
      id: 'SN-778899',
      name: 'Device 3',
      foodWeightGrams: 100,
      isFoodStockHigh: true,
      isWaterTankFull: true,
    ),
  ];

  // ✅  التصحيح: دالة جديدة لإظهار مربع حوار الإضافة
  void _showAddDeviceDialog() {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Device Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Device ID'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () {
              final name = nameController.text;
              final id = idController.text;
              if (name.isNotEmpty && id.isNotEmpty) {
                // إضافة الجهاز الجديد إلى القائمة
                setState(() {
                  _devices.add(
                    PetDevice(
                      id: id,
                      name: name,
                      // قيم افتراضية للجهاز الجديد
                      foodWeightGrams: 0,
                      isFoodStockHigh: true,
                      isWaterTankFull: true,
                    ),
                  );
                });
                Navigator.of(ctx).pop();
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
              ThemeProvider.themeNotifier.value = isDarkMode
                  ? ThemeMode.light
                  : ThemeMode.dark;
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
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              "How is your pet today?",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // استخدام القائمة من الـ State
            ..._devices.map((device) => DeviceCard(device: device)).toList(),

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add New Device'),
                // ✅  التصحيح: تفعيل الزر لاستدعاء الدالة
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
    );
  }
}
