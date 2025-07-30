// lib/screens/lunch_main_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lunch_book/model/lunch_models.dart';
import '../controllers/lunch_controller.dart';
import 'package:intl/intl.dart';

class LunchMainScreen extends StatelessWidget {
  final LunchController controller = Get.put(LunchController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => controller.isLoading.value
            ? Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: controller.currentTab.value,
                children: [
                  _buildHomeTab(),
                  _buildAddEntryTab(),
                  _buildMembersTab(),
                  _buildHistoryTab(),
                  _buildSettingsTab(),
                ],
              ),
      ),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: controller.currentTab.value,
          onTap: (index) => controller.currentTab.value = index,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle),
              label: 'Add Entry',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Members'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Text(
            'Lunch Book Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            'Track your group lunch expenses',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          // Summary Cards
          Obx(() {
            final summary = controller.lunchSummary.value;
            if (summary == null) return SizedBox.shrink();

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Expenses',
                        '\$${summary.totalExpenses.toStringAsFixed(2)}',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Entries',
                        '${summary.totalEntries}',
                        Icons.restaurant,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Average Bill',
                        '\$${summary.averageBill.toStringAsFixed(2)}',
                        Icons.analytics,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Outstanding',
                        '\$${summary.totalOutstanding.toStringAsFixed(2)}',
                        Icons.pending_actions,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

          SizedBox(height: 24),

          // Recent Entries
          Text(
            'Recent Entries',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),

          Obx(
            () => controller.lunchEntries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: controller.lunchEntries.take(5).length,
                    itemBuilder: (context, index) {
                      final entry = controller.lunchEntries[index];
                      return _buildEntryCard(entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddEntryTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Text(
            'Add Lunch Entry',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),

          // Date Selection
          Card(
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.blue),
              title: Text('Date'),
              subtitle: Obx(
                () => Text(
                  DateFormat(
                    'EEEE, MMM dd, yyyy',
                  ).format(controller.selectedDate.value),
                ),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _selectDate(),
            ),
          ),

          SizedBox(height: 16),

          // Restaurant Name
          TextField(
            controller: controller.restaurantController,
            decoration: InputDecoration(
              labelText: 'Restaurant Name (Optional)',
              prefixIcon: Icon(Icons.restaurant),
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 16),

          // Total Bill
          TextField(
            controller: controller.totalBillController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Total Bill Amount',
              prefixIcon: Icon(Icons.attach_money),
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => controller.calculatePerHead(),
            onSubmitted: (value) => controller.checkMemberCountAndSelect(),
          ),

          SizedBox(height: 16),

          // Members Selection
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Members',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.selectAllMembers,
                        child: Text('Select All'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Obx(
                    () => controller.selectedMembers.isEmpty
                        ? Text(
                            'No members selected',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: controller.selectedMembers.map((
                              memberId,
                            ) {
                              final member = controller.getMemberById(memberId);
                              return Chip(
                                label: Text(member?.name ?? 'Unknown'),
                                deleteIcon: Icon(Icons.close, size: 18),
                                onDeleted: () =>
                                    controller.toggleMemberSelection(memberId),
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: controller.showMemberSelectionDialog,
                    icon: Icon(Icons.people),
                    label: Text('Choose Members'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Per Head Amount Display
          Obx(
            () => controller.perHeadAmount.value > 0
                ? Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.calculate, color: Colors.green),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Per Head Amount',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[700],
                                ),
                              ),
                              Text(
                                '\$${controller.perHeadAmount.value.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                          Spacer(),
                          Text(
                            '${controller.selectedMembers.length} members',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox.shrink(),
          ),

          SizedBox(height: 16),

          // Notes
          TextField(
            controller: controller.notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.note),
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 24),

          // Add Entry Button
          ElevatedButton(
            onPressed: controller.addLunchEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: Size(double.infinity, 50),
            ),
            child: Text(
              'Add Lunch Entry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: controller.exportMemberBalancesToCSV,
                    icon: Icon(Icons.file_download),
                    tooltip: 'Export Balances',
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Member balances and payment tracking',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          Expanded(
            child: Obx(
              () => ListView.builder(
                itemCount: controller.members.length,
                itemBuilder: (context, index) {
                  final member = controller.members[index];
                  return _buildMemberCard(member);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'History',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: controller.exportToCSV,
                icon: Icon(Icons.file_download),
                tooltip: 'Export to CSV',
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'All lunch entries',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),

          Expanded(
            child: Obx(
              () => controller.lunchEntries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: controller.lunchEntries.length,
                      itemBuilder: (context, index) {
                        final entry = controller.lunchEntries[index];
                        return _buildHistoryEntryCard(entry);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Text(
            'Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.file_download, color: Colors.blue),
                  title: Text('Export All Data'),
                  subtitle: Text('Export lunch entries to CSV'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: controller.exportToCSV,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.account_balance, color: Colors.green),
                  title: Text('Export Member Balances'),
                  subtitle: Text('Export member balances to CSV'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: controller.exportMemberBalancesToCSV,
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Clear All Data'),
              subtitle: Text('Delete all entries and reset balances'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: controller.clearAllData,
            ),
          ),

          SizedBox(height: 24),

          Text(
            'App Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.developer_mode),
                  title: Text('Developer'),
                  subtitle: Text('Your Company Name'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                Spacer(),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(LunchEntry entry) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            '${entry.date.day}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          entry.restaurant ?? 'Lunch Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy').format(entry.date)),
            Text(
              '${entry.memberCount} members • \$${entry.perHeadAmount.toStringAsFixed(2)} per head',
            ),
          ],
        ),
        trailing: Text(
          '\$${entry.totalBill.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(Member member) {
    final isOwing = member.balance < 0;
    final balanceColor = isOwing ? Colors.red : Colors.green;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: balanceColor,
          child: Text(
            member.name[0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paid: \$${member.totalPaid.toStringAsFixed(2)}'),
            Text('Owed: \$${member.totalOwed.toStringAsFixed(2)}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isOwing ? 'Owes' : 'Clear',
              style: TextStyle(
                fontSize: 12,
                color: balanceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${member.balance.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: balanceColor,
              ),
            ),
          ],
        ),
        onTap: () => controller.showPaymentDialog(member),
      ),
    );
  }

  Widget _buildHistoryEntryCard(LunchEntry entry) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            '${entry.date.day}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          entry.restaurant ?? 'Lunch Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(DateFormat('EEEE, MMM dd, yyyy').format(entry.date)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${entry.totalBill.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _confirmDelete(entry),
            ),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Members: ${entry.memberCount}')),
                    Text(
                      'Per Head: \$${entry.perHeadAmount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text('Participants:'),
                SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: entry.participantIds.map((memberId) {
                    final member = controller.getMemberById(memberId);
                    return Chip(
                      label: Text(
                        member?.name ?? 'Unknown',
                        style: TextStyle(fontSize: 12),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text('Notes: ${entry.notes}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'No lunch entries yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          SizedBox(height: 8),
          Text(
            'Add your first lunch entry to get started',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: controller.selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.selectedDate.value = picked;
    }
  }

  void _confirmDelete(LunchEntry entry) {
    Get.dialog(
      AlertDialog(
        title: Text('Delete Entry'),
        content: Text(
          'Are you sure you want to delete this lunch entry? This will affect member balances.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteLunchEntry(entry.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
