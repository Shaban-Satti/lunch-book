// lib/services/lunch_service.dart
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:lunch_book/model/lunch_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';


class LunchService {
  static const String _membersBoxName = 'members';
  static const String _entriesBoxName = 'lunch_entries';
  static const String _paymentsBoxName = 'payments';

  late Box<Member> _membersBox;
  late Box<LunchEntry> _entriesBox;
  late Box<Payment> _paymentsBox;

  final Uuid _uuid = Uuid();

  // Default members
  static const List<String> defaultMembers = [
    'Adil',
    'Asad',
    'Rufaeel',
    'M Usman',
    'Talat',
    'Umer Farooq',
    'Shaban',
  ];

  // Singleton pattern
  static final LunchService _instance = LunchService._internal();
  factory LunchService() => _instance;
  LunchService._internal();

  /// Initialize Hive and boxes
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    Hive.init(directory.path);

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MemberAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LunchEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PaymentAdapter());
    }

    // Open boxes
    _membersBox = await Hive.openBox<Member>(_membersBoxName);
    _entriesBox = await Hive.openBox<LunchEntry>(_entriesBoxName);
    _paymentsBox = await Hive.openBox<Payment>(_paymentsBoxName);

    // Initialize default members if empty
    if (_membersBox.isEmpty) {
      await _initializeDefaultMembers();
    }
  }

  /// Initialize default members
  Future<void> _initializeDefaultMembers() async {
    for (String name in defaultMembers) {
      final member = Member(
        id: _uuid.v4(),
        name: name,
      );
      await _membersBox.put(member.id, member);
    }
  }

  /// Get all members
  List<Member> getAllMembers() {
    return _membersBox.values.toList();
  }

  /// Get active members
  List<Member> getActiveMembers() {
    return _membersBox.values.where((member) => member.isActive).toList();
  }

  /// Add new member
  Future<void> addMember(String name) async {
    final member = Member(
      id: _uuid.v4(),
      name: name,
    );
    await _membersBox.put(member.id, member);
  }

  /// Update member
  Future<void> updateMember(Member member) async {
    await _membersBox.put(member.id, member);
  }

  /// Add lunch entry
  Future<void> addLunchEntry({
    required DateTime date,
    required double totalBill,
    required List<String> participantIds,
    String? notes,
    String? restaurant,
  }) async {
    final perHeadAmount = totalBill / participantIds.length;
    final now = DateTime.now();

    final entry = LunchEntry(
      id: _uuid.v4(),
      date: date,
      totalBill: totalBill,
      participantIds: participantIds,
      perHeadAmount: perHeadAmount,
      notes: notes,
      restaurant: restaurant,
      createdAt: now,
      updatedAt: now,
    );

    await _entriesBox.put(entry.id, entry);

    // Update member balances
    await _updateMemberBalances(participantIds, perHeadAmount);
  }

  /// Update member balances after adding entry
  Future<void> _updateMemberBalances(List<String> participantIds, double perHeadAmount) async {
    for (String memberId in participantIds) {
      final member = _membersBox.get(memberId);
      if (member != null) {
        final updatedMember = member.copyWith(
          totalOwed: member.totalOwed + perHeadAmount,
        );
        await _membersBox.put(member.id, updatedMember);
      }
    }
  }

  /// Add payment
  Future<void> addPayment({
    required String memberId,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    final payment = Payment(
      id: _uuid.v4(),
      memberId: memberId,
      amount: amount,
      date: date,
      type: 'payment',
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _paymentsBox.put(payment.id, payment);

    // Update member balance
    final member = _membersBox.get(memberId);
    if (member != null) {
      final updatedMember = member.copyWith(
        totalPaid: member.totalPaid + amount,
      );
      await _membersBox.put(member.id, updatedMember);
    }
  }

  /// Get all lunch entries
  List<LunchEntry> getAllEntries() {
    return _entriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get entries by date range
  List<LunchEntry> getEntriesByDateRange(DateTime startDate, DateTime endDate) {
    return _entriesBox.values
        .where((entry) =>
            entry.date.isAfter(startDate.subtract(Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(Duration(days: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get entries by month
  List<LunchEntry> getEntriesByMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    return getEntriesByDateRange(startOfMonth, endOfMonth);
  }

  /// Get all payments
  List<Payment> getAllPayments() {
    return _paymentsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get payments by member
  List<Payment> getPaymentsByMember(String memberId) {
    return _paymentsBox.values
        .where((payment) => payment.memberId == memberId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get lunch summary
  LunchSummary getLunchSummary() {
    final entries = getAllEntries();
    final members = getAllMembers();

    final totalExpenses = entries.fold(0.0, (sum, entry) => sum + entry.totalBill);
    final totalEntries = entries.length;
    final averageBill = totalEntries > 0 ? totalExpenses / totalEntries : 0.0;
    final totalOutstanding = members.fold(0.0, (sum, member) => sum + (member.balance < 0 ? member.balance.abs() : 0));
    final totalPaid = members.fold(0.0, (sum, member) => sum + member.totalPaid);

    return LunchSummary(
      totalExpenses: totalExpenses,
      totalEntries: totalEntries,
      averageBill: averageBill,
      members: members,
      totalOutstanding: totalOutstanding,
      totalPaid: totalPaid,
    );
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _entriesBox.clear();
    await _paymentsBox.clear();
    
    // Reset member balances
    final members = getAllMembers();
    for (Member member in members) {
      final resetMember = member.copyWith(
        totalPaid: 0.0,
        totalOwed: 0.0,
      );
      await _membersBox.put(member.id, resetMember);
    }
  }

  /// Delete lunch entry
  Future<void> deleteLunchEntry(String entryId) async {
    final entry = _entriesBox.get(entryId);
    if (entry != null) {
      // Reverse member balance changes
      for (String memberId in entry.participantIds) {
        final member = _membersBox.get(memberId);
        if (member != null) {
          final updatedMember = member.copyWith(
            totalOwed: member.totalOwed - entry.perHeadAmount,
          );
          await _membersBox.put(member.id, updatedMember);
        }
      }
      await _entriesBox.delete(entryId);
    }
  }

  /// Export to CSV
  Future<String> exportToCSV() async {
    final entries = getAllEntries();
    final members = getAllMembers();
    final memberMap = {for (var member in members) member.id: member.name};

    List<List<String>> csvData = [
      ['Date', 'Restaurant', 'Total Bill', 'Member Count', 'Per Head', 'Participants', 'Notes']
    ];

    for (LunchEntry entry in entries) {
      final participants = entry.participantIds
          .map((id) => memberMap[id] ?? 'Unknown')
          .join(', ');

      csvData.add([
        '${entry.date.day}/${entry.date.month}/${entry.date.year}',
        entry.restaurant ?? 'N/A',
        entry.totalBill.toStringAsFixed(2),
        entry.memberCount.toString(),
        entry.perHeadAmount.toStringAsFixed(2),
        participants,
        entry.notes ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);
    
    // Save to file
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/lunch_book_export.csv');
    await file.writeAsString(csv);
    
    return file.path;
  }


  /// Export member balances to CSV
  Future<String> exportMemberBalancesToCSV() async {
    final members = getAllMembers();

    List<List<String>> csvData = [
      ['Member Name', 'Total Paid', 'Total Owed', 'Balance', 'Status']
    ];

    for (Member member in members) {
      csvData.add([
        member.name,
        member.totalPaid.toStringAsFixed(2),
        member.totalOwed.toStringAsFixed(2),
        member.balance.toStringAsFixed(2),
        member.balance >= 0 ? 'Clear' : 'Owes',
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);
    
    // Save to file
    final directory = await getExternalStorageDirectory();
    final file = File('${directory!.path}/member_balances_export.csv');
    await file.writeAsString(csv);
    
    return file.path;
  }

  /// Close all boxes
  Future<void> close() async {
    await _membersBox.close();
    await _entriesBox.close();
    await _paymentsBox.close();
  }
}