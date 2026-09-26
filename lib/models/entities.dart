class WorkshopSettings {
  const WorkshopSettings({
    required this.name,
    required this.phone,
    required this.address,
    required this.currency,
    required this.localeCode,
    required this.themeMode,
    required this.onboardingDone,
  });

  final String name;
  final String phone;
  final String address;
  final String currency;
  final String localeCode;
  final String themeMode;
  final bool onboardingDone;
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.note,
    this.orderCount = 0,
    this.debtMinor = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String note;
  final int orderCount;
  final int debtMinor;

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
        id: map['id']! as String,
        name: map['name']! as String,
        phone: (map['phone'] ?? '') as String,
        note: (map['note'] ?? '') as String,
        orderCount: (map['order_count'] ?? 0) as int,
        debtMinor: (map['debt_minor'] ?? 0) as int,
      );
}

class RepairOrder {
  const RepairOrder({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deviceCategory,
    required this.deviceName,
    required this.problem,
    required this.conditionNote,
    required this.serialNumber,
    required this.status,
    required this.priority,
    required this.deadlineUtc,
    required this.createdAtUtc,
    required this.totalMinor,
    required this.paidMinor,
    required this.discountMinor,
    required this.archived,
    required this.internalNote,
  });

  final String id;
  final int number;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deviceCategory;
  final String deviceName;
  final String problem;
  final String conditionNote;
  final String serialNumber;
  final String status;
  final String priority;
  final DateTime? deadlineUtc;
  final DateTime createdAtUtc;
  final int totalMinor;
  final int paidMinor;
  final int discountMinor;
  final bool archived;
  final String internalNote;

  int get balanceMinor => totalMinor - paidMinor;
  String get displayNumber => 'MD-${number.toString().padLeft(6, '0')}';

  factory RepairOrder.fromMap(Map<String, Object?> map) => RepairOrder(
        id: map['id']! as String,
        number: map['order_number']! as int,
        customerId: map['customer_id']! as String,
        customerName: (map['customer_name'] ?? '') as String,
        customerPhone: (map['customer_phone'] ?? '') as String,
        deviceCategory: map['device_category']! as String,
        deviceName: map['device_name']! as String,
        problem: map['problem']! as String,
        conditionNote: (map['condition_note'] ?? '') as String,
        serialNumber: (map['serial_number'] ?? '') as String,
        status: map['status']! as String,
        priority: map['priority']! as String,
        deadlineUtc: map['deadline_utc'] == null
            ? null
            : DateTime.parse(map['deadline_utc']! as String),
        createdAtUtc: DateTime.parse(map['created_at_utc']! as String),
        totalMinor: (map['total_minor'] ?? 0) as int,
        paidMinor: (map['paid_minor'] ?? 0) as int,
        discountMinor: (map['discount_minor'] ?? 0) as int,
        archived: (map['archived'] ?? 0) == 1,
        internalNote: (map['internal_note'] ?? '') as String,
      );
}

class Part {
  const Part({
    required this.id,
    required this.name,
    required this.sku,
    required this.compatibility,
    required this.quantity,
    required this.minimumQuantity,
    required this.purchasePriceMinor,
    required this.sellingPriceMinor,
    required this.location,
  });

  final String id;
  final String name;
  final String sku;
  final String compatibility;
  final int quantity;
  final int minimumQuantity;
  final int purchasePriceMinor;
  final int sellingPriceMinor;
  final String location;

  factory Part.fromMap(Map<String, Object?> map) => Part(
        id: map['id']! as String,
        name: map['name']! as String,
        sku: (map['sku'] ?? '') as String,
        compatibility: (map['compatibility'] ?? '') as String,
        quantity: (map['quantity'] ?? 0) as int,
        minimumQuantity: (map['minimum_quantity'] ?? 0) as int,
        purchasePriceMinor: (map['purchase_price_minor'] ?? 0) as int,
        sellingPriceMinor: (map['selling_price_minor'] ?? 0) as int,
        location: (map['location'] ?? '') as String,
      );
}

class OrderEvent {
  const OrderEvent({
    required this.id,
    required this.orderId,
    required this.type,
    required this.descriptionRu,
    required this.descriptionEn,
    required this.createdAtUtc,
  });

  final String id;
  final String orderId;
  final String type;
  final String descriptionRu;
  final String descriptionEn;
  final DateTime createdAtUtc;

  factory OrderEvent.fromMap(Map<String, Object?> map) => OrderEvent(
        id: map['id']! as String,
        orderId: map['order_id']! as String,
        type: map['type']! as String,
        descriptionRu: map['description_ru']! as String,
        descriptionEn: map['description_en']! as String,
        createdAtUtc: DateTime.parse(map['created_at_utc']! as String),
      );
}
