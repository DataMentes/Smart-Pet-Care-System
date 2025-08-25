// lib/features/home/domain/models/pet_device.dart
class PetDevice {
  final String id;
  final String name;
  // ✅  التصحيح: تغيير أسماء الحقول لتطابق الـ Backend
  final double foodLevel;
  final double waterLevel;

  PetDevice({
    required this.id,
    required this.name,
    required this.foodLevel,
    required this.waterLevel,
  });

  factory PetDevice.fromJson(Map<String, dynamic> json) {
    return PetDevice(
      id: json['device_id'],
      name:
          json['device_id'], // الـ Backend لا يوفر اسمًا مخصصًا، سنستخدم الـ ID
      foodLevel: (json['food_level'] ?? 0.0).toDouble(),
      waterLevel: (json['water_level'] ?? 0.0).toDouble(),
    );
  }
}
