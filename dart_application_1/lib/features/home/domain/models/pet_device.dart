// lib/features/home/domain/models/pet_device.dart

class PetDevice {
  final String id; // ✅  التصحيح: إضافة الـ ID
  final String name;
  final double foodWeightGrams;
  final bool isFoodStockHigh;
  final bool isWaterTankFull;

  PetDevice({
    required this.id, // ✅  التصحيح: إضافة الـ ID
    required this.name,
    required this.foodWeightGrams,
    required this.isFoodStockHigh,
    required this.isWaterTankFull,
  });
}
