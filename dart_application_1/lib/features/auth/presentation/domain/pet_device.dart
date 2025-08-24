// lib/features/home/domain/models/pet_device.dart

class PetDevice {
  final String name;
  final double foodWeightGrams; // وزن الأكل بالجرام
  final double waterAmountLiters; // كمية الماء باللتر
  final double foodStorageLevel; // مستوى مخزون الأكل (من 0.0 إلى 1.0)
  final bool isWaterTankFull; // حالة تانك المياه

  PetDevice({
    required this.name,
    required this.foodWeightGrams,
    required this.waterAmountLiters,
    required this.foodStorageLevel,
    required this.isWaterTankFull,
  });
}