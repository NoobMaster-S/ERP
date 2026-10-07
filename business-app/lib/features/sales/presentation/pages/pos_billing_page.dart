import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import 'package:business_app/features/customers/presentation/widgets/add_customer_dialog.dart';
import 'package:business_app/features/inventory/presentation/widgets/add_product_dialog.dart';
import 'package:business_app/features/synchronization/presentation/widgets/sync_status_badge.dart';

class PosBillingPage extends StatefulWidget {
  final SyncEngine syncEngine;
  final VoidCallback? onBackToDashboard;

  const PosBillingPage({
    super.key,
    required this.syncEngine,
    this.onBackToDashboard,
  });

  @override
  State<PosBillingPage> createState() => _PosBillingPageState();
}

class _PosBillingPageState extends State<PosBillingPage> {
  final Map<String, int> _cartQuantities = {};
  String _searchQuery = '';
  String? _selectedCustomerId;
  String _selectedCustomerName = 'Walk-in Customer';
  String _paymentMethod = 'CASH';
  double _discountAmount = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await widget.syncEngine.pullCatalog();
    if (mounted) setState(() {});
  }

  void _addToCart(String productId) {
    setState(() {
      _cartQuantities[productId] = (_cartQuantities[productId] ?? 0) + 1;
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      final current = _cartQuantities[productId] ?? 0;
      if (current <= 1) {
        _cartQuantities.remove(productId);
      } else {
        _cartQuantities[productId] = current - 1;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cartQuantities.clear();
      _discountAmount = 0.0;
      _selectedCustomerId = null;
      _selectedCustomerName = 'Walk-in Customer';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackToDashboard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Dashboard',
                onPressed: widget.onBackToDashboard,
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        title: const Text('POS Terminal & Billing'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: SyncStatusBadge(syncEngine: widget.syncEngine),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Product',
            onPressed: () => AddProductDialog.show(context, widget.syncEngine),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Products & Customers',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing catalog from server...')),
              );
              await _refreshData();
            },
          ),
          if (_cartQuantities.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear Cart',
              onPressed: _clearCart,
            ),
        ],
      ),
      body: StreamBuilder<List<LocalProductsTableData>>(
        stream: widget.syncEngine.db.select(widget.syncEngine.db.localProductsTable).watch(),
        builder: (context, snapshot) {
          final products = snapshot.data ?? [];
          final filteredProducts = products.where((p) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(query) ||
                p.sku.toLowerCase().contains(query) ||
                p.barcode.toLowerCase().contains(query);
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;

              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildProductCatalogSection(filteredProducts),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: _buildCartSummarySection(products),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: _buildProductCatalogSection(filteredProducts),
                  ),
                  if (_cartQuantities.isNotEmpty)
                    _buildMobileCartStickyBar(products),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCatalogSection(List<LocalProductsTableData> products) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search product by name, SKU or barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Product Grid or Empty State
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No products in catalog', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.cloud_download),
                            label: const Text('Pull From Server'),
                            onPressed: _refreshData,
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
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final inCartQty = _cartQuantities[product.id] ?? 0;

                    return Card(
                      elevation: inCartQty > 0 ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: inCartQty > 0
                            ? const BorderSide(color: Color(0xFF3B82F6), width: 1.5)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _addToCart(product.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      product.sku.isNotEmpty ? product.sku : 'SKU',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ),
                                  if (inCartQty > 0)
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: Text(
                                        '$inCartQty',
                                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '₹ ${product.sellingPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stock: ${product.currentStock.toInt()}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: inCartQty > 0 ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _addToCart(product.id),
                                  child: Text(
                                    inCartQty > 0 ? '+ Add More' : 'Add',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCartSummarySection(
    List<LocalProductsTableData> allProducts, {
    BuildContext? sheetContext,
  }) {
    final cartItems = _cartQuantities.entries.map((e) {
      final product = allProducts.firstWhere((p) => p.id == e.key);
      return {
        'product': product,
        'quantity': e.value,
        'lineTotal': e.value * product.sellingPrice,
      };
    }).toList();

    double subtotal = 0.0;
    for (final it in cartItems) {
      subtotal += (it['lineTotal'] as double);
    }
    final grandTotal = (subtotal - _discountAmount).clamp(0.0, double.infinity);

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Text('Current Order', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(${_cartQuantities.values.fold(0, (a, b) => a + b)} Items)', style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                if (sheetContext != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close Sheet',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
              ],
            ),
          ),

          // Customer Selector
          _buildCustomerPicker(),

          // Cart Items List
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
                    child: Text('No items in cart\nTap products to add', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final prod = item['product'] as LocalProductsTableData;
                      final qty = item['quantity'] as int;
                      final total = item['lineTotal'] as double;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        title: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('₹${prod.sellingPrice.toStringAsFixed(2)} each', style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 18),
                              onPressed: () => _removeFromCart(prod.id),
                            ),
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              onPressed: () => _addToCart(prod.id),
                            ),
                            SizedBox(
                              width: 68,
                              child: Text(
                                '₹${total.toStringAsFixed(2)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Order Pricing & Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                    Text('₹ ${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Discount (₹)', style: TextStyle(color: Colors.grey)),
                    SizedBox(
                      width: 90,
                      height: 32,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _discountAmount = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Flexible(
                      child: Text(
                        '₹ ${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment Method Selector
                Row(
                  children: [
                    _buildPayMethodChip('CASH', Icons.money),
                    const SizedBox(width: 6),
                    _buildPayMethodChip('UPI', Icons.qr_code),
                    const SizedBox(width: 6),
                    _buildPayMethodChip('CARD', Icons.credit_card),
                    const SizedBox(width: 6),
                    _buildPayMethodChip('CREDIT', Icons.receipt_long),
                  ],
                ),
                const SizedBox(height: 16),

                // Charge CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _cartQuantities.isEmpty || _isProcessing
                        ? null
                        : () => _handleCheckout(cartItems, grandTotal, sheetContext: sheetContext),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'COMPLETE SALE (₹ ${grandTotal.toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPicker() {
    return StreamBuilder<List<LocalCustomersTableData>>(
      stream: widget.syncEngine.db.select(widget.syncEngine.db.localCustomersTable).watch(),
      builder: (context, snapshot) {
        final customers = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedCustomerId,
                  isDense: true,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Billing Customer',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Walk-in Customer'),
                    ),
                    ...customers.map((c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            '${c.name} (${c.phone.isNotEmpty ? c.phone : "No Phone"})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCustomerId = val;
                      if (val == null) {
                        _selectedCustomerName = 'Walk-in Customer';
                      } else {
                        final matches = customers.where((c) => c.id == val);
                        if (matches.isNotEmpty) {
                          _selectedCustomerName = matches.first.name;
                        }
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.person_add_alt_1, color: Color(0xFF60A5FA), size: 20),
                tooltip: 'Add New Customer',
                onPressed: () async {
                  final newCust = await AddCustomerDialog.show(context, widget.syncEngine);
                  if (newCust != null && mounted) {
                    setState(() {
                      _selectedCustomerId = newCust.id;
                      _selectedCustomerName = newCust.name;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayMethodChip(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF60A5FA) : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 2),
              Text(
                method,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCartStickyBar(List<LocalProductsTableData> allProducts) {
    int totalItems = 0;
    double subtotal = 0.0;
    for (final e in _cartQuantities.entries) {
      final p = allProducts.firstWhere((prod) => prod.id == e.key);
      totalItems += e.value;
      subtotal += e.value * p.sellingPrice;
    }
    final totalPayable = (subtotal - _discountAmount).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$totalItems Items in Cart', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '₹ ${totalPayable.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('View Cart & Pay'),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (sheetContext) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.85,
                    child: _buildCartSummarySection(allProducts, sheetContext: sheetContext),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckout(
    List<Map<String, dynamic>> cartItems,
    double grandTotal, {
    BuildContext? sheetContext,
  }) async {
    setState(() => _isProcessing = true);

    try {
      final itemsPayload = cartItems.map((it) {
        final prod = it['product'] as LocalProductsTableData;
        final qty = it['quantity'] as int;
        return {
          'productId': prod.id,
          'quantity': qty.toDouble(),
          'unitPrice': prod.sellingPrice,
          'taxRate': 0.0,
          'discountAmount': 0.0,
        };
      }).toList();

      final result = await widget.syncEngine.recordSale(
        items: itemsPayload,
        customerId: _selectedCustomerId,
        customerName: _selectedCustomerName,
        discountAmount: _discountAmount,
        paidAmount: grandTotal,
        paymentMethod: _paymentMethod,
      );

      final invoiceNum = result['invoiceNumber'] as String;
      final isSynced = result['isSynced'] as bool;

      if (!mounted) return;

      // 1. Pop the mobile bottom sheet modal so the create view does NOT persist
      if (sheetContext != null && sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }

      // 2. Reset cart state and customer selection
      _clearCart();

      // 3. Show receipt confirmation dialog with actions
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            isSynced ? Icons.check_circle : Icons.cloud_off,
            color: isSynced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            size: 48,
          ),
          title: Text(isSynced ? 'Sale Complete!' : 'Sale Recorded (Offline)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Invoice # $invoiceNum',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSynced ? const Color(0xFF064E3B) : const Color(0xFF78350F),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSynced ? 'Authoritative Cloud Sequence' : 'Queued in Drift Outbox',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSynced ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Customer: $_selectedCustomerName'),
              Text('Total Paid: ₹ ${grandTotal.toStringAsFixed(2)} via $_paymentMethod'),
              const SizedBox(height: 12),
              const Text('Stock deducted in Drift local database.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            if (widget.onBackToDashboard != null)
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onBackToDashboard?.call();
                },
                child: const Text('Back to Dashboard'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('New Sale'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording sale: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
