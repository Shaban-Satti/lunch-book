import 'package:device_info_plus/device_info_plus.dart';
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
    if (members.any(
      (member) => member.name.toLowerCase() == name.toLowerCase(),
    )) {
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
    final hasEntries = lunchEntries.any(
      (entry) => entry.participantIds.contains(member.id),
    );
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

  // /// Add custom amount to member
  // Future<void> addCustomAmount(String memberId) async {
  //   final amount = double.tryParse(customAmountController.text);
  //   if (amount == null) {
  //     Get.snackbar('Error', 'Please enter a valid amount');
  //     return;
  //   }

  //   final note = customNoteController.text.trim();
  //   if (note.isEmpty) {
  //     Get.snackbar('Error', 'Please enter a note for this custom amount');
  //     return;
  //   }

  //   try {
  //     isLoading.value = true;

  //     await _lunchService.addCustomAmount(
  //       memberId: memberId,
  //       amount: amount,
  //       note: note,
  //       date: DateTime.now(),
  //     );

  //     customAmountController.clear();
  //     customNoteController.clear();
  //     await loadData();

  //     Get.snackbar(
  //       'Success',
  //       'Custom amount added successfully!',
  //       backgroundColor: Colors.green,
  //       colorText: Colors.white,
  //     );
  //     Get.back();
  //   } catch (e) {
  //     Get.snackbar('Error', 'Failed to add custom amount: $e');
  //   } finally {
  //     isLoading.value = false;
  //   }
  // }

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
          ElevatedButton(onPressed: addNewMember, child: Text('Add Member')),
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

  // Add these variables to your LunchController class
  var isCustomAmountPositive = true.obs; // Add this observable variable

  /// Show custom amount dialog with improved UX
  void showCustomAmountDialog(Member member) {
    customAmountController.clear();
    customNoteController.clear();
    isCustomAmountPositive.value = true; // Reset to positive

    Get.dialog(
      AlertDialog(
        title: Text('Add Custom Amount for ${member.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Balance Display
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: member.balance >= 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: member.balance >= 0
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      member.balance >= 0
                          ? Icons.account_balance_wallet
                          : Icons.warning,
                      color: member.balance >= 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Current Balance: PKR ${member.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: member.balance >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Amount Type Selection
              Text(
                'Select Amount Type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),

              Obx(
                () => Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => isCustomAmountPositive.value = true,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isCustomAmountPositive.value
                                ? Colors.green.shade100
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: isCustomAmountPositive.value
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle,
                                color: isCustomAmountPositive.value
                                    ? Colors.green
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Credit (+)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCustomAmountPositive.value
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => isCustomAmountPositive.value = false,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: !isCustomAmountPositive.value
                                ? Colors.red.shade100
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: !isCustomAmountPositive.value
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_circle,
                                color: !isCustomAmountPositive.value
                                    ? Colors.red
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Debit (-)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !isCustomAmountPositive.value
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Amount Input
              Obx(
                () => TextField(
                  controller: customAmountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'PKR ',
                    prefixIcon: Icon(
                      isCustomAmountPositive.value ? Icons.add : Icons.remove,
                      color: isCustomAmountPositive.value
                          ? Colors.green
                          : Colors.red,
                    ),
                    border: OutlineInputBorder(),
                    helperText: isCustomAmountPositive.value
                        ? 'This amount will be added to member\'s account'
                        : 'This amount will be deducted from member\'s account',
                    helperStyle: TextStyle(
                      color: isCustomAmountPositive.value
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),

              // Note Input
              TextField(
                controller: customNoteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note/Reason *',
                  border: OutlineInputBorder(),
                  hintText: isCustomAmountPositive.value
                      ? 'e.g., Paid extra, Advance payment, etc.'
                      : 'e.g., Borrowed money, Extra expense, etc.',
                  prefixIcon: Icon(Icons.note),
                ),
              ),

              SizedBox(height: 8),

              // Preview
              Obx(() {
                final amount =
                    double.tryParse(customAmountController.text) ?? 0.0;
                final finalAmount = isCustomAmountPositive.value
                    ? amount
                    : -amount;
                final newBalance = member.balance + finalAmount;

                if (amount > 0) {
                  return Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.preview, color: Colors.blue, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New Balance: PKR ${newBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          Obx(
            () => ElevatedButton(
              onPressed: () => addCustomAmount(member.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCustomAmountPositive.value
                    ? Colors.green
                    : Colors.red,
              ),
              child: Text(
                isCustomAmountPositive.value ? 'Add Credit' : 'Add Debit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Updated addCustomAmount method to handle the sign
  Future<void> addCustomAmount(String memberId) async {
    final amount = double.tryParse(customAmountController.text);
    if (amount == null || amount <= 0) {
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

      // Apply the sign based on selection
      final finalAmount = isCustomAmountPositive.value ? amount : -amount;

      await _lunchService.addCustomAmount(
        memberId: memberId,
        amount: finalAmount,
        note: note,
        date: DateTime.now(),
      );

      customAmountController.clear();
      customNoteController.clear();
      await loadData();

      Get.snackbar(
        'Success',
        isCustomAmountPositive.value
            ? 'Credit added successfully!'
            : 'Debit added successfully!',
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
  //   /// Show custom amount dialog
  // void showCustomAmountDialog(Member member) {
  //   customAmountController.clear();
  //   customNoteController.clear();
  //   Get.dialog(
  //     AlertDialog(
  //       title: Text('Add Custom Amount for ${member.name}'),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('Current Balance: PKR ${member.balance.toStringAsFixed(2)}'),
  //           SizedBox(height: 16),
  //           TextField(
  //             controller: customAmountController,
  //             keyboardType: TextInputType.numberWithOptions(decimal: true),
  //             decoration: InputDecoration(
  //               labelText: 'Amount (+ for credit, - for debit)',
  //               prefixText: 'PKR',
  //               border: OutlineInputBorder(),
  //               helperText: 'Use negative value to deduct amount',
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           TextField(
  //             controller: customNoteController,
  //             maxLines: 2,
  //             decoration: InputDecoration(
  //               labelText: 'Note/Reason',
  //               border: OutlineInputBorder(),
  //               hintText: 'e.g., Borrowed money, Extra expense, etc.',
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
  //         ElevatedButton(
  //           onPressed: () => addCustomAmount(member.id),
  //           child: Text('Add Amount'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

  // Future<String> exportToCSV() async {
  //   final entries = getAllEntries();
  //   final members = getAllMembers();
  //   final memberMap = {for (var member in members) member.id: member.name};

  //   List<List<String>> csvData = [
  //     [
  //       'Date',
  //       'Restaurant',
  //       'Total Bill',
  //       'Member Count',
  //       'Per Head',
  //       'Participants',
  //       'Notes',
  //     ],
  //   ];

  //   for (LunchEntry entry in entries) {
  //     final participants = entry.participantIds
  //         .map((id) => memberMap[id] ?? 'Unknown')
  //         .join(', ');

  //     csvData.add([
  //       '${entry.date.day}/${entry.date.month}/${entry.date.year}',
  //       entry.restaurant ?? 'N/A',
  //       entry.totalBill.toStringAsFixed(2),
  //       entry.memberCount.toString(),
  //       entry.perHeadAmount.toStringAsFixed(2),
  //       participants,
  //       entry.notes ?? '',
  //     ]);
  //   }

  //   return await exportToDownloads('lunch_book_export', csvData);
  // }

  // Future<String> exportMemberBalancesToCSV() async {
  //   final members = getAllMembers();

  //   List<List<String>> csvData = [
  //     ['Member Name', 'Total Paid', 'Total Owed', 'Balance', 'Status'],
  //   ];

  //   for (Member member in members) {
  //     csvData.add([
  //       member.name,
  //       member.totalPaid.toStringAsFixed(2),
  //       member.totalOwed.toStringAsFixed(2),
  //       member.balance.toStringAsFixed(2),
  //       member.balance >= 0 ? 'Clear' : 'Owes',
  //     ]);
  //   }

  //   return await exportToDownloads('member_balances_export', csvData);
  // }

  // Future<String> exportToDownloads(
  //   String fileName,
  //   List<List<String>> csvData,
  // ) async {
  //   final status = await Permission.storage.request();
  //   if (!status.isGranted) throw Exception('Storage permission denied');

  //   final baseDir = Directory('/storage/emulated/0/Download');
  //   final customDir = Directory('${baseDir.path}/LunchBook');

  //   if (!await customDir.exists()) {
  //     await customDir.create(recursive: true);
  //   }

  //   final file = File('${customDir.path}/$fileName.csv');
  //   final csv = const ListToCsvConverter().convert(csvData);
  //   await file.writeAsString(csv);
  //   return file.path;
  // }
  // Replace your existing exportToDownloads method with this updated version
  ///////
  ///
  ///
  ///
  ///
  ///
  // Add these imports at the top of your file

  // Replace your existing export methods with these updated versions

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ - Request media permissions
        final status = await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ].request();
        return status.values.every((status) => status.isGranted);
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12 - Request manage external storage
        if (await Permission.manageExternalStorage.isDenied) {
          final status = await Permission.manageExternalStorage.request();
          return status.isGranted;
        }
        return true;
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Try multiple paths for Downloads directory
      final possiblePaths = [
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
        Directory('/sdcard/Download'),
        Directory('/sdcard/Downloads'),
      ];

      for (final dir in possiblePaths) {
        if (await dir.exists()) {
          return dir;
        }
      }

      // If no standard Downloads folder found, create one in external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final downloadsDir = Directory(
          '${externalDir.parent.parent.parent.parent.path}/Download',
        );
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
      }
    }

    return null;
  }

  Future<String> exportToDownloads(
    String fileName,
    List<List<String>> csvData,
  ) async {
    try {
      // Request permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        // Show permission dialog
        await _showPermissionDialog();
        throw Exception(
          'Storage permission is required to save files to Downloads',
        );
      }

      // Get Downloads directory
      Directory? downloadsDir = await _getDownloadsDirectory();

      if (downloadsDir == null) {
        throw Exception('Could not access Downloads folder');
      }

      // Create LunchBook subdirectory
      final lunchBookDir = Directory('${downloadsDir.path}/LunchBook');
      if (!await lunchBookDir.exists()) {
        await lunchBookDir.create(recursive: true);
      }

      // Create filename with timestamp
      final now = DateTime.now();
      final timestamp =
          '${now.day}-${now.month}-${now.year}_${now.hour}-${now.minute}';
      final file = File('${lunchBookDir.path}/${fileName}_$timestamp.csv');

      // Convert to CSV and write
      final csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  Future<void> _showPermissionDialog() async {
    Get.dialog(
      AlertDialog(
        title: Text('Storage Permission Required'),
        content: Text(
          'To save files to Downloads folder, please grant storage permission in the next dialog. '
          'If permission is denied, files will be saved to app folder instead.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('OK')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Alternative method that tries Downloads first, falls back to app directory
  Future<String> exportToDownloadsWithFallback(
    String fileName,
    List<List<String>> csvData,
  ) async {
    try {
      // First try to save to Downloads
      try {
        return await exportToDownloads(fileName, csvData);
      } catch (e) {
        print('Failed to save to Downloads: $e');
        // Fall back to app directory
        return await _exportToAppDirectory(fileName, csvData);
      }
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  Future<String> _exportToAppDirectory(
    String fileName,
    List<List<String>> csvData,
  ) async {
    // Fallback to app's external storage
    final appDir = await getExternalStorageDirectory();
    if (appDir == null) {
      throw Exception('Could not access app storage');
    }

    final exportDir = Directory('${appDir.path}/LunchBookExports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final now = DateTime.now();
    final timestamp =
        '${now.day}-${now.month}-${now.year}_${now.hour}-${now.minute}';
    final file = File('${exportDir.path}/${fileName}_$timestamp.csv');

    final csv = const ListToCsvConverter().convert(csvData);
    await file.writeAsString(csv);

    return file.path;
  }

  // Updated main export methods
  Future<String> exportToCSV() async {
    try {
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

      final filePath = await exportToDownloadsWithFallback(
        'lunch_book_export',
        csvData,
      );

      // Determine if file was saved to Downloads or app directory
      final isInDownloads = filePath.contains('/Download/LunchBook/');

      Get.snackbar(
        'Export Successful',
        isInDownloads
            ? 'File saved to Downloads/LunchBook folder'
            : 'File saved to app folder (Downloads access not available)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );

      return filePath;
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      throw e;
    }
  }

  Future<String> exportMemberBalancesToCSV() async {
    try {
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

      final filePath = await exportToDownloadsWithFallback(
        'member_balances_export',
        csvData,
      );

      final isInDownloads = filePath.contains('/Download/LunchBook/');

      Get.snackbar(
        'Export Successful',
        isInDownloads
            ? 'File saved to Downloads/LunchBook folder'
            : 'File saved to app folder (Downloads access not available)',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );

      return filePath;
    } catch (e) {
      Get.snackbar(
        'Export Failed',
        'Error: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      throw e;
    }
  }

  // Helper method to open Downloads/LunchBook folder in file manager
  Future<void> openDownloadsFolder() async {
    try {
      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir != null) {
        final lunchBookDir = Directory('${downloadsDir.path}/LunchBook');
        if (await lunchBookDir.exists()) {
          Get.dialog(
            AlertDialog(
              title: Text('Files Location'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your exported files are saved in:'),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      'Downloads/LunchBook/',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You can find these files in your device\'s Downloads folder under the LunchBook subfolder.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Get.back(), child: Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not locate Downloads folder: $e');
    }
  }
  //////////////////////////////////////////
  // Future<String> exportToDownloads(
  //   String fileName,
  //   List<List<String>> csvData,
  // ) async {
  //   try {
  //     // For Android 10+ (API 29+), use app-specific external storage
  //     // This doesn't require WRITE_EXTERNAL_STORAGE permission
  //     Directory? downloadsDir;

  //     if (Platform.isAndroid) {
  //       // Try to get the Downloads directory
  //       try {
  //         downloadsDir = Directory('/storage/emulated/0/Download');

  //         // Check if we can access the Downloads directory
  //         if (!await downloadsDir.exists()) {
  //           // Fallback to app's external storage directory
  //           final appDir = await getExternalStorageDirectory();
  //           if (appDir != null) {
  //             downloadsDir = Directory('${appDir.path}/Downloads');
  //           }
  //         }
  //       } catch (e) {
  //         // If Downloads directory is not accessible, use app's external storage
  //         final appDir = await getExternalStorageDirectory();
  //         if (appDir != null) {
  //           downloadsDir = Directory('${appDir.path}/Downloads');
  //         }
  //       }
  //     }

  //     // Fallback to documents directory if external storage is not available
  //     downloadsDir ??= await getApplicationDocumentsDirectory();

  //     // Create the directory if it doesn't exist
  //     if (!await downloadsDir.exists()) {
  //       await downloadsDir.create(recursive: true);
  //     }

  //     // Create filename with timestamp to avoid conflicts
  //     final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     final file = File('${downloadsDir.path}/${fileName}_$timestamp.csv');

  //     // Convert to CSV and write
  //     final csv = const ListToCsvConverter().convert(csvData);
  //     await file.writeAsString(csv);

  //     return file.path;
  //   } catch (e) {
  //     throw Exception('Failed to export CSV: $e');
  //   }
  // }

  // // Alternative method using MediaStore for Android 10+ (Scoped Storage)
  // Future<String> exportToDownloadsMediaStore(
  //   String fileName,
  //   List<List<String>> csvData,
  // ) async {
  //   try {
  //     // This method works better for newer Android versions
  //     final csv = const ListToCsvConverter().convert(csvData);
  //     final timestamp = DateTime.now().millisecondsSinceEpoch;
  //     final fullFileName = '${fileName}_$timestamp.csv';

  //     if (Platform.isAndroid) {
  //       // Use app's external files directory (no permission needed)
  //       final appDir = await getExternalStorageDirectory();
  //       if (appDir != null) {
  //         final exportDir = Directory('${appDir.path}/LunchBookExports');
  //         if (!await exportDir.exists()) {
  //           await exportDir.create(recursive: true);
  //         }

  //         final file = File('${exportDir.path}/$fullFileName');
  //         await file.writeAsString(csv);
  //         return file.path;
  //       }
  //     }

  //     // Fallback for other platforms or if external storage is not available
  //     final documentsDir = await getApplicationDocumentsDirectory();
  //     final file = File('${documentsDir.path}/$fullFileName');
  //     await file.writeAsString(csv);
  //     return file.path;
  //   } catch (e) {
  //     throw Exception('Failed to export CSV: $e');
  //   }
  // }

  // // Updated export methods to use the new approach
  // Future<String> exportToCSV() async {
  //   try {
  //     final entries = getAllEntries();
  //     final members = getAllMembers();
  //     final memberMap = {for (var member in members) member.id: member.name};

  //     List<List<String>> csvData = [
  //       [
  //         'Date',
  //         'Restaurant',
  //         'Total Bill',
  //         'Member Count',
  //         'Per Head',
  //         'Participants',
  //         'Notes',
  //       ],
  //     ];

  //     for (LunchEntry entry in entries) {
  //       final participants = entry.participantIds
  //           .map((id) => memberMap[id] ?? 'Unknown')
  //           .join(', ');

  //       csvData.add([
  //         '${entry.date.day}/${entry.date.month}/${entry.date.year}',
  //         entry.restaurant ?? 'N/A',
  //         entry.totalBill.toStringAsFixed(2),
  //         entry.memberCount.toString(),
  //         entry.perHeadAmount.toStringAsFixed(2),
  //         participants,
  //         entry.notes ?? '',
  //       ]);
  //     }

  //     final filePath = await exportToDownloadsMediaStore(
  //       'lunch_book_export',
  //       csvData,
  //     );

  //     // Show success message with file location
  //     Get.snackbar(
  //       'Export Successful',
  //       'File saved to: $filePath',
  //       backgroundColor: Colors.green,
  //       colorText: Colors.white,
  //       duration: Duration(seconds: 5),
  //     );

  //     return filePath;
  //   } catch (e) {
  //     Get.snackbar('Export Failed', 'Error: $e');
  //     throw e;
  //   }
  // }

  // Future<String> exportMemberBalancesToCSV() async {
  //   try {
  //     final members = getAllMembers();

  //     List<List<String>> csvData = [
  //       ['Member Name', 'Total Paid', 'Total Owed', 'Balance', 'Status'],
  //     ];

  //     for (Member member in members) {
  //       csvData.add([
  //         member.name,
  //         member.totalPaid.toStringAsFixed(2),
  //         member.totalOwed.toStringAsFixed(2),
  //         member.balance.toStringAsFixed(2),
  //         member.balance >= 0 ? 'Clear' : 'Owes',
  //       ]);
  //     }

  //     final filePath = await exportToDownloadsMediaStore(
  //       'member_balances_export',
  //       csvData,
  //     );

  //     // Show success message with file location
  //     Get.snackbar(
  //       'Export Successful',
  //       'File saved to: $filePath',
  //       backgroundColor: Colors.green,
  //       colorText: Colors.white,
  //       duration: Duration(seconds: 5),
  //     );

  //     return filePath;
  //   } catch (e) {
  //     Get.snackbar('Export Failed', 'Error: $e');
  //     throw e;
  //   }
  // }

  // Optional: Method to open file manager to show exported files
  Future<void> openExportFolder() async {
    try {
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        final exportDir = Directory('${appDir.path}/LunchBookExports');
        if (await exportDir.exists()) {
          // You can use external packages like 'open_file' to open the folder
          // or show the path to user
          Get.dialog(
            AlertDialog(
              title: Text('Exported Files Location'),
              content: SelectableText(exportDir.path),
              actions: [
                TextButton(onPressed: () => Get.back(), child: Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not open export folder: $e');
    }
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
