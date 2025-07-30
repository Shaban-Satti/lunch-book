// lib/models/lunch_models.dart
import 'package:hive/hive.dart';

part 'lunch_models.g.dart';

@HiveType(typeId: 0)
class Member extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  double totalPaid;

  @HiveField(3)
  double totalOwed;

  @HiveField(4)
  bool isActive;

  Member({
    required this.id,
    required this.name,
    this.totalPaid = 0.0,
    this.totalOwed = 0.0,
    this.isActive = true,
  });

  double get balance => totalPaid - totalOwed;

  Member copyWith({
    String? id,
    String? name,
    double? totalPaid,
    double? totalOwed,
    bool? isActive,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      totalPaid: totalPaid ?? this.totalPaid,
      totalOwed: totalOwed ?? this.totalOwed,
      isActive: isActive ?? this.isActive,
    );
  }
}

@HiveType(typeId: 1)
class LunchEntry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final double totalBill;

  @HiveField(3)
  final List<String> participantIds;

  @HiveField(4)
  final double perHeadAmount;

  @HiveField(5)
  final String? notes;

  @HiveField(6)
  final String? restaurant;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final DateTime updatedAt;

  LunchEntry({
    required this.id,
    required this.date,
    required this.totalBill,
    required this.participantIds,
    required this.perHeadAmount,
    this.notes,
    this.restaurant,
    required this.createdAt,
    required this.updatedAt,
  });

  int get memberCount => participantIds.length;

  LunchEntry copyWith({
    String? id,
    DateTime? date,
    double? totalBill,
    List<String>? participantIds,
    double? perHeadAmount,
    String? notes,
    String? restaurant,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LunchEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      totalBill: totalBill ?? this.totalBill,
      participantIds: participantIds ?? this.participantIds,
      perHeadAmount: perHeadAmount ?? this.perHeadAmount,
      notes: notes ?? this.notes,
      restaurant: restaurant ?? this.restaurant,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@HiveType(typeId: 2)
class Payment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String memberId;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String type; // 'payment' or 'settlement'

  @HiveField(5)
  final String? notes;

  @HiveField(6)
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.type,
    this.notes,
    required this.createdAt,
  });

  Payment copyWith({
    String? id,
    String? memberId,
    double? amount,
    DateTime? date,
    String? type,
    String? notes,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Summary model for displaying statistics
class LunchSummary {
  final double totalExpenses;
  final int totalEntries;
  final double averageBill;
  final List<Member> members;
  final double totalOutstanding;
  final double totalPaid;

  LunchSummary({
    required this.totalExpenses,
    required this.totalEntries,
    required this.averageBill,
    required this.members,
    required this.totalOutstanding,
    required this.totalPaid,
  });
}

// CSV Export model
class CSVExportData {
  final String date;
  final String restaurant;
  final double totalBill;
  final int memberCount;
  final double perHead;
  final String participants;
  final String notes;

  CSVExportData({
    required this.date,
    required this.restaurant,
    required this.totalBill,
    required this.memberCount,
    required this.perHead,
    required this.participants,
    required this.notes,
  });

  List<String> toCSVRow() {
    return [
      date,
      restaurant,
      totalBill.toStringAsFixed(2),
      memberCount.toString(),
      perHead.toStringAsFixed(2),
      participants,
      notes,
    ];
  }
}