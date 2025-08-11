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
  var memberNameController = TextEditingController();
  var customAmountController = TextEditingController();
  var customNoteController = TextEditingController();
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
    memberNameController.dispose();
    customAmountController.dispose();
    customNoteController.dispose();
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

  /// Auto select all members
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

  /// Add new member
  Future<void> addNewMember() async {
    final name = memberNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Error', 'Please enter a member name');
      return;
    }

    // Check if member already exists
    if (members.any((member) => member.name.toLowerCase() == name.toLowerCase())) {
      Get.snackbar('Error', 'Member with this name already exists');
      return;
    }

    try {
      isLoading.value = true;

      await _lunchService.addMember(name);
      memberNameController.clear();
      await loadData();

      Get.snackbar(
        'Success',
        'Member added successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to add member: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete member
  Future<void> deleteMember(Member member) async {
    // Check if member has any balance or entries
    final hasEntries = lunchEntries.any((entry) => entry.participantIds.contains(member.id));
    final hasBalance = member.totalPaid != 0 || member.totalOwed != 0;

    if (hasEntries || hasBalance) {
      Get.dialog(
        AlertDialog(
          title: Text('Cannot Delete Member'),
          content: Text(
            'This member has existing lunch entries or balance. You can only deactivate them.',
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Get.back();
                deactivateMember(member);
              },
              child: Text('Deactivate'),
            ),
          ],
        ),
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                Get.back();
                isLoading.value = true;
                await _lunchService.deleteMember(member.id);
                await loadData();
                Get.snackbar(
                  'Success',
                  'Member deleted successfully!',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.snackbar('Error', 'Failed to delete member: $e');
              } finally {
                isLoading.value = false;
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Deactivate member
  Future<void> deactivateMember(Member member) async {
    try {
      isLoading.value = true;
      await _lunchService.deactivateMember(member.id);
      await loadData();
      Get.snackbar(
        'Success',
        'Member deactivated successfully!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to deactivate member: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Add custom amount to member
  Future<void> addCustomAmount(String memberId) async {
    final amount = double.tryParse(customAmountController.text);
    if (amount == null) {
      Get.snackbar('Error', 'Please enter a valid amount');
      return;
    }

    final note = customNoteController.text.trim();
    if (note.isEmpty) {
      Get.snackbar('Error', 'Please enter a note for this custom amount');
      return;
    }

    try {
      isLoading.value = true;

      await _lunchService.addCustomAmount(
        memberId: memberId,
        amount: amount,
        note: note,
        date: DateTime.now(),
      );

      customAmountController.clear();
      customNoteController.clear();
      await loadData();

      Get.snackbar(
        'Success',
        'Custom amount added successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back();
    } catch (e) {
      Get.snackbar('Error', 'Failed to add custom amount: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Show add member dialog
  void showAddMemberDialog() {
    memberNameController.clear();
    Get.dialog(
      AlertDialog(
        title: Text('Add New Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: memberNameController,
              decoration: InputDecoration(
                labelText: 'Member Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: addNewMember,
            child: Text('Add Member'),
          ),
        ],
      ),
    );
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

  /// Show custom amount dialog
  void showCustomAmountDialog(Member member) {
    customAmountController.clear();
    customNoteController.clear();
    Get.dialog(
      AlertDialog(
        title: Text('Add Custom Amount for ${member.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Balance: PKR ${member.balance.toStringAsFixed(2)}'),
            SizedBox(height: 16),
            TextField(
              controller: customAmountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (+ for credit, - for debit)',
                prefixText: 'PKR',
                border: OutlineInputBorder(),
                helperText: 'Use negative value to deduct amount',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: customNoteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note/Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g., Borrowed money, Extra expense, etc.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => addCustomAmount(member.id),
            child: Text('Add Amount'),
          ),
        ],
      ),
    );
  }

  /// Show member options dialog
  void showMemberOptionsDialog(Member member) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.name,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Balance: PKR ${member.balance.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.payment, color: Colors.green),
              title: Text('Add Payment'),
              onTap: () {
                Get.back();
                showPaymentDialog(member);
              },
            ),
            ListTile(
              leading: Icon(Icons.add_box, color: Colors.blue),
              title: Text('Add Custom Amount'),
              subtitle: Text('Add credit/debit with note'),
              onTap: () {
                Get.back();
                showCustomAmountDialog(member);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Member'),
              onTap: () {
                Get.back();
                deleteMember(member);
              },
            ),
          ],
        ),
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
    final status = await Permission.storage.request();
    if (!status.isGranted) throw Exception('Storage permission denied');

    final baseDir = Directory('/storage/emulated/0/Download');
    final customDir = Directory('${baseDir.path}/LunchBook');

    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    final file = File('${customDir.path}/$fileName.csv');
    final csv = const ListToCsvConverter().convert(csvData);
    await file.writeAsString(csv);
    return file.path;
  }

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

  /// Get all members (including inactive)
  List<Member> getAllMembers() {
    return _lunchService.getAllMembers();
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
        selectAllMembers();
        Get.snackbar(
          'Auto Selected',
          'All 7 members selected automatically',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
      } else {
        showMemberSelectionDialog();
      }
    }
  }
}