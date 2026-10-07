import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:business_app/core/database/app_database.dart';
import 'package:business_app/core/sync/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Point to an invalid unreachable port to simulate complete disconnection from API
    final unreachableClient = GraphQLClient(
      link: HttpLink('http://127.0.0.1:59999/graphql/'),
      cache: GraphQLCache(store: InMemoryStore()),
    );
    syncEngine = SyncEngine(db: db, client: unreachableClient);

    // Seed local inventory stock offline in Drift SQLite
    await db.into(db.localProductsTable).insert(
      LocalProductsTableCompanion(
        id: const Value('prod-1'),
        serverId: const Value('srv-prod-1'),
        businessId: const Value('demo-retail'),
        name: const Value('Masala Chai 250g'),
        sku: const Value('CHAI-250'),
        barcode: const Value('890111222'),
        sellingPrice: const Value(120.0),
        costPrice: const Value(90.0),
        currentStock: const Value(50.0),
        isSynced: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await db.into(db.localProductsTable).insert(
      LocalProductsTableCompanion(
        id: const Value('prod-2'),
        serverId: const Value('srv-prod-2'),
        businessId: const Value('demo-retail'),
        name: const Value('Whole Wheat Bread 400g'),
        sku: const Value('BREAD-400'),
        barcode: const Value('890333444'),
        sellingPrice: const Value(45.0),
        costPrice: const Value(30.0),
        currentStock: const Value(20.0),
        isSynced: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Offline POS Billing & Order Taking (Disconnected from API)', () {
    test('Can take orders and generate bills when disconnected from API', () async {
      // Simulate taking an order: 2x Masala Chai + 1x Bread
      final cartItems = [
        {
          'productId': 'prod-1',
          'quantity': 2.0,
          'unitPrice': 120.0,
          'taxRate': 0.0,
          'discountAmount': 0.0,
        },
        {
          'productId': 'prod-2',
          'quantity': 1.0,
          'unitPrice': 45.0,
          'taxRate': 0.0,
          'discountAmount': 0.0,
        },
      ];

      final totalPayable = (2.0 * 120.0) + (1.0 * 45.0); // 285.0

      // Execute offline checkout
      final result = await syncEngine.recordSale(
        items: cartItems,
        customerName: 'Walk-in Customer',
        discountAmount: 0.0,
        paidAmount: totalPayable,
        paymentMethod: 'CASH',
      );

      // Verify receipt details generated offline
      expect(result['isSynced'], isFalse);
      expect(result['invoiceNumber'].toString().startsWith('OFFL-'), isTrue);
      expect(result['grandTotal'], equals(285.0));
      expect(result['paidAmount'], equals(285.0));

      // Verify order saved locally in Drift SQLite LocalSalesTable
      final sales = await db.select(db.localSalesTable).get();
      expect(sales.length, equals(1));
      expect(sales.first.invoiceNumber, equals(result['invoiceNumber']));
      expect(sales.first.grandTotal, equals(285.0));
      expect(sales.first.isSynced, isFalse);
      expect(sales.first.paymentStatus, equals('PAID'));

      // Verify product stock decremented offline immediately in LocalProductsTable
      final prod1 = await (db.select(db.localProductsTable)..where((p) => p.id.equals('prod-1'))).getSingle();
      final prod2 = await (db.select(db.localProductsTable)..where((p) => p.id.equals('prod-2'))).getSingle();
      expect(prod1.currentStock, equals(48.0)); // 50 - 2 = 48
      expect(prod2.currentStock, equals(19.0)); // 20 - 1 = 19

      // Verify transaction queued in Drift SyncOutboxTable for deferred cloud sync
      final outbox = await db.select(db.syncOutboxTable).get();
      expect(outbox.length, equals(1));
      expect(outbox.first.mutationType, equals('CREATE_SALE'));
      expect(outbox.first.entityType, equals('Sale'));
      expect(outbox.first.status, equals(OutboxStatus.pending));
    });

    test('Can take multiple successive offline bills with unique invoice references', () async {
      // Order 1
      final sale1 = await syncEngine.recordSale(
        items: [
          {'productId': 'prod-1', 'quantity': 1.0, 'unitPrice': 120.0}
        ],
        paidAmount: 120.0,
      );

      // Order 2
      final sale2 = await syncEngine.recordSale(
        items: [
          {'productId': 'prod-2', 'quantity': 2.0, 'unitPrice': 45.0}
        ],
        paidAmount: 90.0,
      );

      expect(sale1['invoiceNumber'], isNot(equals(sale2['invoiceNumber'])));
      expect(sale1['isSynced'], isFalse);
      expect(sale2['isSynced'], isFalse);

      final sales = await db.select(db.localSalesTable).get();
      expect(sales.length, equals(2));

      final outbox = await db.select(db.syncOutboxTable).get();
      expect(outbox.length, equals(2));
    });

    test('Can create customer offline and bill against that customer', () async {
      // 1. Create customer offline
      final customer = await syncEngine.createCustomer(
        name: 'Offline Customer Test',
        phone: '9876540000',
        initialBalance: 0.0,
      );

      expect(customer.name, equals('Offline Customer Test'));

      // 2. Bill against that customer offline
      final sale = await syncEngine.recordSale(
        items: [
          {'productId': 'prod-1', 'quantity': 1.0, 'unitPrice': 120.0}
        ],
        customerId: customer.id,
        customerName: customer.name,
        paidAmount: 120.0,
      );

      expect(sale['isSynced'], isFalse);

      final outbox = await db.select(db.syncOutboxTable).get();
      // Should have 1 CREATE_CUSTOMER and 1 CREATE_SALE in outbox
      expect(outbox.length, equals(2));
      expect(outbox.any((o) => o.mutationType == 'CREATE_CUSTOMER'), isTrue);
      expect(outbox.any((o) => o.mutationType == 'CREATE_SALE'), isTrue);
    });
  });
}
