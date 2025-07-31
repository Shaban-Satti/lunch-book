// lib/controllers/lunch_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lunch_book/model/lunch_models.dart';
import '../services/lunch_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:csv/csv.dart';

class LunchController extends GetxController {
  final LunchService _lunchService = LunchService();

  // Observable variables
  var members = <Member>[].obs;
  var lunchEntries = <LunchEntry>[].obs;
  var payments = <Payment>[].obs;
  var selectedMembers = <String>[].obs;
  var isLoading = false.obs;
  var currentTab = 0.obs;

  // Form variables
  var totalBillController = TextEditingController();
  var notesController = TextEditingController();
  var restaurantController = TextEditingController();
  var paymentAmountController = TextEditingController();
  var selectedDate = DateTime.now().obs;
  var perHeadAmount = 0.0.obs;

  // Summary data
  var lunchSummary = Rxn<LunchSummary>();

  @override
  void onInit() {
    super.onInit();
    initializeService();
  }

  @override
  void onClose() {
    totalBillController.dispose();
    notesController.dispose();
    restaurantController.dispose();
    paymentAmountController.dispose();
    super.onClose();
  }

  /// Initialize the lunch service
  Future<void> initializeService() async {
    try {
      isLoading.value = true;
      await _lunchService.init();
      await loadData();
    } catch (e) {
      Get.snackbar('Error', 'Failed to initialize: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load all data
  Future<void> loadData() async {
    members.value = _lunchService.getActiveMembers();
    lunchEntries.value = _lunchService.getAllEntries();
    payments.value = _lunchService.getAllPayments();
    lunchSummary.value = _lunchService.getLunchSummary();
  }

  /// Calculate per head amount
  void calculatePerHead() {
    final totalBill = double.tryParse(totalBillController.text) ?? 0.0;
    if (selectedMembers.isNotEmpty && totalBill > 0) {
      perHeadAmount.value = totalBill / selectedMembers.length;
    } else {
      perHeadAmount.value = 0.0;
    }
  }

  /// Toggle member selection
  void toggleMemberSelection(String memberId) {
    if (selectedMembers.contains(memberId)) {
      selectedMembers.remove(memberId);
    } else {
      selectedMembers.add(memberId);
    }
    calculatePerHead();
  }

  /// Auto select all members (7 members)
  void selectAllMembers() {
    selectedMembers.clear();
    selectedMembers.addAll(members.map((member) => member.id));
    calculatePerHead();
  }

  /// Show member selection dialog
  void showMemberSelectionDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Select Members'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose members for this lunch:'),
              SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Obx(
                      () => CheckboxListTile(
                        title: Text(member.name),
                        subtitle: Text(
                          'Balance: PKR ${member.balance.toStringAsFixed(2)}',
                        ),
                        value: selectedMembers.contains(member.id),
                        onChanged: (value) => toggleMemberSelection(member.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              calculatePerHead();
              Get.back();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Add lunch entry
  Future<void> addLunchEntry() async {
    if (selectedMembers.isEmpty) {
      Get.snackbar('Error', 'Please select at least one member');
      return;
    }

    final totalBill = double.tryParse(totalBillController.text);
    if (totalBill == null || totalBill <= 0) {
      Get.snackbar('Error', 'Please enter a valid total bill amount');
      return;
    }

    try {
      isLoading.value = true;

      await _lunchService.addLunchEntry(
        date: selectedDate.value,
        totalBill: totalBill,
        participantIds: selectedMembers.toList(),
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        restaurant: restaurantController.text.trim().isEmpty
            ? null
            : restaurantController.text.trim(),
      );

      // Clear form
      clearForm();

      // Reload data
      await loadData();

      Get.snackbar(
        'Success',
        'Lunch entry added successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to add lunch entry: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Add payment
  Future<void> addPayment(String memberId) async {
    final amount = double.tryParse(paymentAmountController.text);
    if (amount == null || amount <= 0) {
      Get.snackbar('Error', 'Please enter a valid payment amount');
      return;
    }

    try {
      isLoading.value = true;

      await _lunchService.addPayment(
        memberId: memberId,
        amount: amount,
        date: DateTime.now(),
      );

      paymentAmountController.clear();
      await loadData();

      Get.snackbar(
        'Success',
        'Payment added successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to add payment: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Show payment dialog
  void showPaymentDialog(Member member) {
    paymentAmountController.clear();
    Get.dialog(
      AlertDialog(
        title: Text('Add Payment for ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Balance: PKR ${member.balance.toStringAsFixed(2)}'),
            if (member.balance < 0)
              Text(
                'Amount Owed: PKR ${member.balance.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 16),
            TextField(
              controller: paymentAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: 'PKR',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => addPayment(member.id),
            child: Text('Add Payment'),
          ),
        ],
      ),
    );
  }

  /// Clear form
  void clearForm() {
    totalBillController.clear();
    notesController.clear();
    restaurantController.clear();
    selectedMembers.clear();
    selectedDate.value = DateTime.now();
    perHeadAmount.value = 0.0;
  }

  /// Delete lunch entry
  Future<void> deleteLunchEntry(String entryId) async {
    try {
      isLoading.value = true;
      await _lunchService.deleteLunchEntry(entryId);
      await loadData();
      Get.snackbar(
        'Success',
        'Lunch entry deleted successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete entry: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Export data to CSV
  // Future<void> exportToCSV() async {
  //   try {
  //     isLoading.value = true;
  //     final filePath = await _lunchService.exportToCSV();
  //     Get.snackbar(
  //       'Success',
  //       'Data exported to: $filePath',
  //       backgroundColor: Colors.green,
  //       colorText: Colors.white,
  //       duration: Duration(seconds: 4),
  //     );
  //   } catch (e) {
  //     Get.snackbar('Error', 'Failed to export data: $e');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }
  Future<String> exportToCSV() async {
    final entries = getAllEntries();
    final members = getAllMembers();
    final memberMap = {for (var member in members) member.id: member.name};

    List<List<String>> csvData = [
      [
        'Date',
        'Restaurant',
        'Total Bill',
        'Member Count',
        'Per Head',
        'Participants',
        'Notes',
      ],
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

    return await exportToDownloads('lunch_book_export', csvData);
  }

  Future<String> exportMemberBalancesToCSV() async {
    final members = getAllMembers();

    List<List<String>> csvData = [
      ['Member Name', 'Total Paid', 'Total Owed', 'Balance', 'Status'],
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

    return await exportToDownloads('member_balances_export', csvData);
  }

  Future<String> exportToDownloads(
    String fileName,
    List<List<String>> csvData,
  ) async {
    // Request storage permission
    final status = await Permission.storage.request();
    if (!status.isGranted) throw Exception('Storage permission denied');

    // Define path to Downloads/LunchBook folde r
    final baseDir = Directory('/storage/emulated/0/Download');
    final customDir = Directory('${baseDir.path}/LunchBook');

    // Create folder if it doesn't exist
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    // Define full file path
    final file = File('${customDir.path}/$fileName.csv');

    // Convert to CSV
    final csv = const ListToCsvConverter().convert(csvData);

    // Write file
    await file.writeAsString(csv);

    return file.path;
  }
  // Future<String> exportToDownloads(
  //   String fileName,
  //   List<List<String>> csvData,
  // ) async {
  //   // Ask for storage permission
  //   print('hello');
  //   final status = await Permission.storage.request();
  //   if (!status.isGranted) throw Exception('Storage permission denied');

  //   // Get Downloads directory
  //   final directory = Directory('/storage/emulated/0/Download');

  //   // Create file
  //   final file = File('${directory.path}/$fileName.csv');
  //   final csv = const ListToCsvConverter().convert(csvData);

  //   // Write file
  //   await file.writeAsString(csv);
  //   return file.path;
  // }

  /// Export member balances to CSV
  // Future<void> exportMemberBalances() async {
  //   try {
  //     isLoading.value = true;
  //     final filePath = await _lunchService.exportMemberBalancesToCSV();
  //     Get.snackbar(
  //       'Success',
  //       'Member balances exported to: $filePath',
  //       backgroundColor: Colors.green,
  //       colorText: Colors.white,
  //       duration: Duration(seconds: 4),
  //     );
  //   } catch (e) {
  //     Get.snackbar('Error', 'Failed to export balances: $e');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

  /// Clear all data
  Future<void> clearAllData() async {
    Get.dialog(
      AlertDialog(
        title: Text('Clear All Data'),
        content: Text(
          'Are you sure you want to clear all lunch entries and payments? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                Get.back();
                isLoading.value = true;
                await _lunchService.clearAllData();
                await loadData();
                Get.snackbar(
                  'Success',
                  'All data cleared successfully!',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar('Error', 'Failed to clear data: $e');
              } finally {
                isLoading.value = false;
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Get all lunch entries
  List<LunchEntry> getAllEntries() {
    return lunchEntries.toList();
  }

  /// Get all members
  List<Member> getAllMembers() {
    return members.toList();
  }

  /// Get member by ID
  Member? getMemberById(String id) {
    return members.firstWhereOrNull((member) => member.id == id);
  }

  /// Get entries for current month
  List<LunchEntry> getCurrentMonthEntries() {
    final now = DateTime.now();
    return _lunchService.getEntriesByMonth(now);
  }

  /// Get total amount owed by all members
  double getTotalOwed() {
    return members.fold(
      0.0,
      (sum, member) => sum + (member.balance < 0 ? member.balance.abs() : 0),
    );
  }

  /// Get total amount paid by all members
  double getTotalPaid() {
    return members.fold(0.0, (sum, member) => sum + member.totalPaid);
  }

  /// Check if member count matches automatic selection
  void checkMemberCountAndSelect() {
    final totalBill = double.tryParse(totalBillController.text) ?? 0.0;

    if (totalBill > 0) {
      if (members.length == 7) {
        // Auto select all 7 members
        selectAllMembers();
        Get.snackbar(
          'Auto Selected',
          'All 7 members selected automatically',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        // Show selection dialog
        showMemberSelectionDialog();
      }
    }
  }
}
