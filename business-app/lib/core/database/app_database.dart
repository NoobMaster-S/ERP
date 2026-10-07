import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'erp_business_app.sqlite'));
      return NativeDatabase.createInBackground(file);
    } catch (_) {
      return NativeDatabase.memory();
    }
  });
}

// Sync Outbox Table for offline-first transactional mutations
enum OutboxStatus { pending, inFlight, completed, failed }

class SyncOutboxTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().withLength(min: 36, max: 128)();
  TextColumn get clientMutationId => text()();
  TextColumn get mutationType => text()(); // e.g. 'CREATE_SALE', 'CREATE_CUSTOMER'
  TextColumn get entityType => text()();   // e.g. 'Sale', 'Customer'
  TextColumn get localEntityId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get status => intEnum<OutboxStatus>()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttemptedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}

// Local Cached Customers
class LocalCustomersTable extends Table {
  TextColumn get id => text()(); // local or server UUID
  TextColumn get serverId => text().nullable()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Local Cached Products
class LocalProductsTable extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().withDefault(const Constant(''))();
  TextColumn get barcode => text().withDefault(const Constant(''))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Local Offline Sales
class LocalSalesTable extends Table {
  TextColumn get id => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get businessId => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get customerId => text().nullable()();
  RealColumn get grandTotal => real()();
  RealColumn get paidAmount => real()();
  TextColumn get paymentStatus => text()();
  TextColumn get idempotencyKey => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  SyncOutboxTable,
  LocalCustomersTable,
  LocalProductsTable,
  LocalSalesTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
