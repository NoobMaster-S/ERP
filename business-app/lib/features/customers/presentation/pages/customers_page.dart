import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../widgets/add_customer_dialog.dart';

class CustomersPage extends StatefulWidget {
  final SyncEngine syncEngine;

  const CustomersPage({super.key, required this.syncEngine});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Accounts & Khata'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Customer',
            onPressed: () => AddCustomerDialog.show(context, widget.syncEngine),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync with Cloud',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing customer accounts...')),
              );
              await widget.syncEngine.pullCatalog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocalCustomersTableData>>(
              stream: widget.syncEngine.db.select(widget.syncEngine.db.localCustomersTable).watch(),
              builder: (context, snapshot) {
                final rawCustomers = snapshot.data ?? [];
                final seen = <String>{};
                final customers = <LocalCustomersTableData>[];
                for (final c in rawCustomers) {
                  final key = (c.serverId != null && c.serverId!.isNotEmpty)
                      ? 'srv_${c.serverId}'
                      : (c.phone.isNotEmpty ? 'phone_${c.phone}' : 'name_${c.name.trim().toLowerCase()}');
                  if (seen.add(key)) {
                    customers.add(c);
                  }
                }
                final filtered = customers.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No customers found in local store'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('Fetch Customers'),
                              onPressed: () => widget.syncEngine.pullCatalog(),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Customer'),
                              onPressed: () => AddCustomerDialog.show(context, widget.syncEngine),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final hasBalance = item.currentBalance > 0;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasBalance ? const Color(0xFF78350F) : const Color(0xFF1E293B),
                          child: Icon(
                            Icons.person,
                            color: hasBalance ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                          ),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          item.phone.isNotEmpty ? item.phone : 'No Phone Number',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹ ${item.currentBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: hasBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                            ),
                            Text(
                              hasBalance ? 'Due / Receivable' : 'Settled',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasBalance ? const Color(0xFFEF4444) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
        onPressed: () => AddCustomerDialog.show(context, widget.syncEngine),
      ),
    );
  }
}
