import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:business_app/core/database/app_database.dart';
import 'package:business_app/core/sync/sync_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SyncEngine syncEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // Create a dummy GraphQLClient with empty cache and local link
    final client = GraphQLClient(
      link: HttpLink('http://127.0.0.1:8000/graphql/'),
      cache: GraphQLCache(store: InMemoryStore()),
    );
    syncEngine = SyncEngine(db: db, client: client);
  });

  tearDown(() async {
    await db.close();
  });

  group('Product Creation in Mobile App', () {
    test('createProduct inserts into local Drift database and logs to outbox', () async {
      final product = await syncEngine.createProduct(
        name: 'Organic Basmati Rice 5kg',
        sku: 'RICE-BAS-001',
        barcode: '8901234567890',
        sellingPrice: 450.0,
        costPrice: 380.0,
        initialStock: 75.0,
      );

      expect(product.name, equals('Organic Basmati Rice 5kg'));
      expect(product.sku, equals('RICE-BAS-001'));
      expect(product.sellingPrice, equals(450.0));
      expect(product.costPrice, equals(380.0));
      expect(product.currentStock, equals(75.0));

      // Check Drift SQLite table directly
      final allProducts = await db.select(db.localProductsTable).get();
      expect(allProducts.length, equals(1));
      expect(allProducts.first.name, equals('Organic Basmati Rice 5kg'));

      // Check Outbox record created
      final outboxEntries = await db.select(db.syncOutboxTable).get();
      expect(outboxEntries.length, equals(1));
      expect(outboxEntries.first.mutationType, equals('CREATE_PRODUCT'));
      expect(outboxEntries.first.entityType, equals('Product'));
    });

    test('createProduct auto-generates SKU if left empty', () async {
      final product = await syncEngine.createProduct(
        name: 'Fresh Dairy Milk 1L',
        sellingPrice: 60.0,
      );

      expect(product.sku.startsWith('SKU-'), isTrue);
      expect(product.sellingPrice, equals(60.0));
    });
  });

  group('Customer Creation in Mobile App', () {
    test('createCustomer inserts into local Drift database and logs to outbox', () async {
      final customer = await syncEngine.createCustomer(
        name: 'Suresh Patel',
        phone: '9876543210',
        email: 'suresh@example.com',
        initialBalance: 250.0,
        creditLimit: 5000.0,
      );

      expect(customer.name, equals('Suresh Patel'));
      expect(customer.phone, equals('9876543210'));
      expect(customer.email, equals('suresh@example.com'));
      expect(customer.currentBalance, equals(250.0));

      // Check Drift SQLite table directly
      final allCustomers = await db.select(db.localCustomersTable).get();
      expect(allCustomers.length, equals(1));
      expect(allCustomers.first.name, equals('Suresh Patel'));

      // Check Outbox record created
      final outboxEntries = await db.select(db.syncOutboxTable).get();
      expect(outboxEntries.length, equals(1));
      expect(outboxEntries.first.mutationType, equals('CREATE_CUSTOMER'));
      expect(outboxEntries.first.entityType, equals('Customer'));
    });
  });
}
