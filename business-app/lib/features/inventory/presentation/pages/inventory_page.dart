import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../widgets/add_product_dialog.dart';

class InventoryPage extends StatefulWidget {
  final SyncEngine syncEngine;

  const InventoryPage({super.key, required this.syncEngine});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Product',
            onPressed: () => AddProductDialog.show(context, widget.syncEngine),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync with Cloud',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing inventory catalog...')),
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
                hintText: 'Search products by name, SKU or barcode...',
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
            child: StreamBuilder<List<LocalProductsTableData>>(
              stream: widget.syncEngine.db.select(widget.syncEngine.db.localProductsTable).watch(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                final filtered = products.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return p.name.toLowerCase().contains(q) ||
                      p.sku.toLowerCase().contains(q) ||
                      p.barcode.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('No products in local inventory'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('Fetch Catalog'),
                              onPressed: () => widget.syncEngine.pullCatalog(),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Product'),
                              onPressed: () => AddProductDialog.show(context, widget.syncEngine),
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
                    final isLowStock = item.currentStock <= 5;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? const Color(0xFF78350F) : const Color(0xFF1E293B),
                          child: Icon(
                            Icons.inventory_2,
                            color: isLowStock ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                          ),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'SKU: ${item.sku.isNotEmpty ? item.sku : "N/A"} • Cost: ₹${item.costPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹ ${item.sellingPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isLowStock ? const Color(0xFF78350F) : const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.currentStock.toInt()} in stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isLowStock ? const Color(0xFFFCD34D) : const Color(0xFF34D399),
                                ),
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
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        onPressed: () => AddProductDialog.show(context, widget.syncEngine),
      ),
    );
  }
}
