import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_app/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:business_app/core/sync/sync_engine.dart';
import 'package:business_app/core/database/app_database.dart';
import 'package:business_app/features/synchronization/presentation/widgets/sync_status_badge.dart';
import 'package:business_app/features/sales/presentation/pages/pos_billing_page.dart';
import 'package:business_app/features/inventory/presentation/pages/inventory_page.dart';
import 'package:business_app/features/customers/presentation/pages/customers_page.dart';
import 'package:business_app/features/inventory/presentation/widgets/add_product_dialog.dart';
import 'package:business_app/features/customers/presentation/widgets/add_customer_dialog.dart';

class DashboardPage extends StatefulWidget {
  final SyncEngine syncEngine;

  const DashboardPage({super.key, required this.syncEngine});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'POS Billing'),
    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    // Warm up offline database by pulling product and customer catalog
    widget.syncEngine.pullCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        return Scaffold(
          appBar: _selectedIndex == 0
              ? AppBar(
                  title: const Text('ERP Business POS'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: SyncStatusBadge(syncEngine: widget.syncEngine),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      },
                    ),
                  ],
                )
              : null,
          body: Row(
            children: [
              if (isDesktop || isTablet)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  labelType: isDesktop ? NavigationRailLabelType.all : NavigationRailLabelType.selected,
                  destinations: _destinations
                      .map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)))
                      .toList(),
                ),
              Expanded(
                child: _buildBodyContent(),
              ),
            ],
          ),
          bottomNavigationBar: (!isDesktop && !isTablet)
              ? NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  destinations: _destinations,
                )
              : null,
        );
      },
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 1:
        return PosBillingPage(
          syncEngine: widget.syncEngine,
          onBackToDashboard: () => setState(() => _selectedIndex = 0),
        );
      case 2:
        return InventoryPage(syncEngine: widget.syncEngine);
      case 3:
        return CustomersPage(syncEngine: widget.syncEngine);
      case 4:
        return _buildSettingsView();
      case 0:
      default:
        return _buildDashboardOverview(context);
    }
  }

  Widget _buildDashboardOverview(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Overview",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Sync with Cloud',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing data from server...')),
                  );
                  await widget.syncEngine.pullCatalog();
                  await widget.syncEngine.syncPendingOutbox();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Real Metric Cards connected to Drift
          StreamBuilder<List<LocalSalesTableData>>(
            stream: widget.syncEngine.db.select(widget.syncEngine.db.localSalesTable).watch(),
            builder: (context, salesSnapshot) {
              final allSales = salesSnapshot.data ?? [];
              final todaySales = allSales.where((s) => s.createdAt.isAfter(todayStart)).toList();
              final todayTotal = todaySales.fold(0.0, (acc, s) => acc + s.grandTotal);

              return StreamBuilder<List<LocalCustomersTableData>>(
                stream: widget.syncEngine.db.select(widget.syncEngine.db.localCustomersTable).watch(),
                builder: (context, custSnapshot) {
                  final customers = custSnapshot.data ?? [];
                  final totalReceivables = customers.fold(0.0, (acc, c) => acc + c.currentBalance);
                  final dueCustomersCount = customers.where((c) => c.currentBalance > 0).length;

                  return StreamBuilder<List<LocalProductsTableData>>(
                    stream: widget.syncEngine.db.select(widget.syncEngine.db.localProductsTable).watch(),
                    builder: (context, prodSnapshot) {
                      final products = prodSnapshot.data ?? [];
                      final lowStockCount = products.where((p) => p.currentStock <= 5).length;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildMetricCard(
                            title: "Today's Sales",
                            value: "₹ ${todayTotal.toStringAsFixed(2)}",
                            subtext: "${todaySales.length} Transactions",
                            icon: Icons.trending_up,
                            color: const Color(0xFF10B981),
                          ),
                          _buildMetricCard(
                            title: "Outstanding Receivables",
                            value: "₹ ${totalReceivables.toStringAsFixed(2)}",
                            subtext: "$dueCustomersCount Accounts Due",
                            icon: Icons.account_balance_wallet_outlined,
                            color: const Color(0xFF3B82F6),
                          ),
                          _buildMetricCard(
                            title: "Low Stock Items",
                            value: "$lowStockCount Products",
                            subtext: "Threshold ≤ 5",
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),
          const Text(
            "Quick POS Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                label: 'New Sale / Bill',
                icon: Icons.shopping_cart_checkout,
                isPrimary: true,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildActionButton(
                label: 'View Inventory',
                icon: Icons.inventory_2_outlined,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _buildActionButton(
                label: 'Customer Khata',
                icon: Icons.people_outline,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
              _buildActionButton(
                label: 'Add Product',
                icon: Icons.add_box_outlined,
                onTap: () => AddProductDialog.show(context, widget.syncEngine),
              ),
              _buildActionButton(
                label: 'Add Customer',
                icon: Icons.person_add_alt_1_outlined,
                onTap: () => AddCustomerDialog.show(context, widget.syncEngine),
              ),
              _buildActionButton(
                label: 'Sync Outbox',
                icon: Icons.sync,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await widget.syncEngine.syncPendingOutbox();
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Sync completed.')),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 28),
          const Text(
            "Recent Offline & Online Transactions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<LocalSalesTableData>>(
            stream: (widget.syncEngine.db.select(widget.syncEngine.db.localSalesTable)
                  ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
                .watch(),
            builder: (context, snapshot) {
              final sales = snapshot.data ?? [];

              if (sales.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No sales recorded yet on this device'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Ring Up First Sale'),
                            onPressed: () => setState(() => _selectedIndex = 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.take(5).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final sale = sales[idx];
                    final isSynced = sale.isSynced;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSynced ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                        child: Icon(
                          isSynced ? Icons.cloud_done : Icons.cloud_off,
                          color: isSynced ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Invoice #${sale.invoiceNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isSynced
                            ? 'Synced to Cloud • Authoritative'
                            : 'Stored in Drift SQLite • Pending Outbox',
                        style: TextStyle(fontSize: 12, color: isSynced ? Colors.grey : const Color(0xFFFCD34D)),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹ ${sale.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            sale.paymentStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: sale.paymentStatus == 'PAID' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Icon(icon, size: 20, color: color),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtext, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSettingsView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Settings & Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync_alt, color: Color(0xFF3B82F6)),
              title: const Text('Synchronization Engine'),
              subtitle: const Text('Trigger full catalog refresh and flush pending outbox'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await widget.syncEngine.pullCatalog();
                  await widget.syncEngine.syncPendingOutbox();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sync triggered successfully!')),
                    );
                  }
                },
                child: const Text('Sync Now'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: Color(0xFF10B981)),
              title: const Text('Drift Local SQLite Storage'),
              subtitle: const Text('High-performance client-side offline database'),
              trailing: const Chip(label: Text('Active')),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign Out'),
              subtitle: const Text('Switch active business or user account'),
              onTap: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
          ),
        ],
      ),
    );
  }
}
