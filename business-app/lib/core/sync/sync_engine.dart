import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

enum SyncEngineStatus { idle, syncing, offline, error }

class SyncEngine {
  final AppDatabase _db;
  final GraphQLClient _client;
  final Connectivity _connectivity;

  AppDatabase get db => _db;
  GraphQLClient get client => _client;

  final _statusController = StreamController<SyncEngineStatus>.broadcast();
  Stream<SyncEngineStatus> get statusStream => _statusController.stream;

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isOffline = false;

  bool get isOffline => _isOffline;
  set isOffline(bool val) {
    _isOffline = val;
    _statusController.add(val ? SyncEngineStatus.offline : SyncEngineStatus.idle);
  }

  SyncEngine({
    required AppDatabase db,
    required GraphQLClient client,
    Connectivity? connectivity,
  })  : _db = db,
        _client = client,
        _connectivity = connectivity ?? Connectivity() {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((dynamic event) {
      final hasConnection = event is List<ConnectivityResult>
          ? event.any((r) => r != ConnectivityResult.none)
          : event != ConnectivityResult.none;
      if (hasConnection) {
        _isOffline = false;
        syncPendingOutbox();
      } else {
        _isOffline = true;
        _statusController.add(SyncEngineStatus.offline);
      }
    });
  }

  /// Triggers outbox synchronization and returns status message
  Future<String> syncPendingOutbox() async {
    if (_isSyncing) return 'Sync is currently in progress...';
    _isSyncing = true;
    _statusController.add(SyncEngineStatus.syncing);

    try {
      // 1. Fetch pending outbox records
      final pendingEntries = await (_db.select(_db.syncOutboxTable)
            ..where((tbl) => tbl.status.equals(OutboxStatus.pending.index))
            ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)]))
          .get();

      if (pendingEntries.isEmpty) {
        _statusController.add(SyncEngineStatus.idle);
        _isSyncing = false;
        return 'Outbox is up to date (0 pending items).';
      }

      // 2. Prepare GraphQL sync batch mutation input
      final itemsInput = pendingEntries.map((e) {
        return {
          'idempotencyKey': e.idempotencyKey,
          'clientMutationId': e.clientMutationId,
          'mutationType': e.mutationType,
          'entityType': e.entityType,
          'payloadJson': e.payloadJson,
        };
      }).toList();

      const mutation = r'''
        mutation IngestSyncBatch($input: SyncBatchInput!) {
          ingestSyncBatch(input: $input) {
            processedCount
            results {
              idempotencyKey
              isSuccess
              serverEntityId
              errorMessage
            }
          }
        }
      ''';

      final result = await _client.mutate(
        MutationOptions(
          document: gql(mutation),
          variables: {'input': {'items': itemsInput}},
        ),
      );

      if (result.hasException) {
        final errText = result.exception.toString();
        final isAuthErr = errText.toLowerCase().contains('authentication') ||
            errText.toLowerCase().contains('credentials');

        // Increment retry count on pending records
        for (final entry in pendingEntries) {
          final newCount = entry.retryCount + 1;
          await (_db.update(_db.syncOutboxTable)..where((t) => t.id.equals(entry.id)))
              .write(
            SyncOutboxTableCompanion(
              retryCount: Value(newCount),
              status: Value(
                newCount >= entry.maxRetries
                    ? OutboxStatus.failed
                    : OutboxStatus.pending,
              ),
              lastAttemptedAt: Value(DateTime.now()),
              lastError: Value(errText),
            ),
          );
        }
        _statusController.add(SyncEngineStatus.error);
        return isAuthErr
            ? 'Authentication required: please log in to sync with cloud.'
            : 'Sync error: $errText';
      } else {
        final results = result.data?['ingestSyncBatch']?['results'] as List<dynamic>?;
        if (results != null) {
          _isOffline = false;
          for (final res in results) {
            final key = res['idempotencyKey'] as String;
            final isSuccess = res['isSuccess'] as bool;
            final serverId = res['serverEntityId'] as String?;

            await (_db.update(_db.syncOutboxTable)
                  ..where((t) => t.idempotencyKey.equals(key)))
                .write(
              SyncOutboxTableCompanion(
                status: Value(
                  isSuccess ? OutboxStatus.completed : OutboxStatus.failed,
                ),
                lastAttemptedAt: Value(DateTime.now()),
              ),
            );

            // If success and serverId returned, update corresponding local entity
            if (isSuccess && serverId != null) {
              await (_db.update(_db.localSalesTable)
                    ..where((t) => t.idempotencyKey.equals(key)))
                  .write(LocalSalesTableCompanion(
                serverId: Value(serverId),
                isSynced: const Value(true),
              ));

              final matchingEntries = pendingEntries.where((e) => e.idempotencyKey == key);
              if (matchingEntries.isNotEmpty) {
                final entry = matchingEntries.first;
                if (entry.entityType == 'Product') {
                  await (_db.update(_db.localProductsTable)
                        ..where((t) => t.id.equals(entry.localEntityId)))
                      .write(LocalProductsTableCompanion(
                    serverId: Value(serverId),
                    isSynced: const Value(true),
                  ));
                } else if (entry.entityType == 'Customer') {
                  await (_db.update(_db.localCustomersTable)
                        ..where((t) => t.id.equals(entry.localEntityId)))
                      .write(LocalCustomersTableCompanion(
                    serverId: Value(serverId),
                    isSynced: const Value(true),
                  ));
                }
              }
            }
          }
        }
        _statusController.add(SyncEngineStatus.idle);
        return 'Sync completed! ${pendingEntries.length} transaction(s) synchronized.';
      }
    } catch (e) {
      _isOffline = true;
      _statusController.add(SyncEngineStatus.error);
      return 'Sync connection error: $e';
    } finally {
      _isSyncing = false;
    }
  }

  /// Pulls catalog products and customers from GraphQL and updates Drift cache
  Future<void> pullCatalog() async {
    try {
      const query = r'''
        query GetCatalog {
          products {
            id
            name
            sku
            barcode
            sellingPrice
            costPrice
          }
          customers {
            id
            name
            phone
            currentBalance
          }
        }
      ''';

      final result = await _client.query(
        QueryOptions(
          document: gql(query),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      ).timeout(const Duration(seconds: 2));

      if (result.hasException) {
        _isOffline = true;
        _statusController.add(SyncEngineStatus.offline);
        return;
      }

      if (result.data != null) {
        _isOffline = false;
        _statusController.add(SyncEngineStatus.idle);
        final productsData = result.data?['products'] as List<dynamic>?;
        if (productsData != null) {
          for (final p in productsData) {
            await _db.into(_db.localProductsTable).insertOnConflictUpdate(
              LocalProductsTableCompanion(
                id: Value(p['id'] as String),
                serverId: Value(p['id'] as String),
                businessId: const Value('demo-retail'),
                name: Value(p['name'] as String),
                sku: Value((p['sku'] as String?) ?? ''),
                barcode: Value((p['barcode'] as String?) ?? ''),
                sellingPrice: Value((p['sellingPrice'] as num).toDouble()),
                costPrice: Value((p['costPrice'] as num).toDouble()),
                currentStock: const Value(100.0),
                isSynced: const Value(true),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }

        final customersData = result.data?['customers'] as List<dynamic>?;
        if (customersData != null) {
          for (final c in customersData) {
            await _db.into(_db.localCustomersTable).insertOnConflictUpdate(
              LocalCustomersTableCompanion(
                id: Value(c['id'] as String),
                serverId: Value(c['id'] as String),
                businessId: const Value('demo-retail'),
                name: Value(c['name'] as String),
                phone: Value((c['phone'] as String?) ?? ''),
                currentBalance: Value((c['currentBalance'] as num).toDouble()),
                isSynced: const Value(true),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Offline fallback: keep existing Drift SQLite cache
      _isOffline = true;
      _statusController.add(SyncEngineStatus.offline);
    }
  }

  /// Records a POS Sale offline-first in Drift and synchronizes with server
  Future<Map<String, dynamic>> recordSale({
    required List<Map<String, dynamic>> items,
    String? customerId,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    double discountAmount = 0.0,
    required double paidAmount,
    String paymentMethod = 'CASH',
  }) async {
    const uuid = Uuid();
    final localSaleId = uuid.v4();
    final idempotencyKey = uuid.v4();
    final timestamp = DateTime.now();
    final dateStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}';
    final tempSuffix = (timestamp.millisecondsSinceEpoch % 100000).toString().padLeft(5, '0');
    final clientInvoiceRef = 'OFFL-$dateStr-$tempSuffix';

    double subtotal = 0.0;
    for (final it in items) {
      final qty = (it['quantity'] as num).toDouble();
      final price = (it['unitPrice'] as num).toDouble();
      subtotal += qty * price;
    }
    final grandTotal = (subtotal - discountAmount).clamp(0.0, double.infinity);

    // 1. Save locally to Drift LocalSalesTable immediately (offline-first)
    await _db.into(_db.localSalesTable).insert(
      LocalSalesTableCompanion(
        id: Value(localSaleId),
        serverId: const Value(null),
        businessId: const Value('demo-retail'),
        invoiceNumber: Value(clientInvoiceRef),
        customerId: Value(customerId),
        grandTotal: Value(grandTotal),
        paidAmount: Value(paidAmount),
        paymentStatus: Value(paidAmount >= grandTotal ? 'PAID' : 'PARTIAL'),
        idempotencyKey: Value(idempotencyKey),
        isSynced: const Value(false),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 2. Decrement local product stock in LocalProductsTable
    for (final it in items) {
      final prodId = it['productId'] as String;
      final qty = (it['quantity'] as num).toDouble();
      final currentProd = await (_db.select(_db.localProductsTable)..where((t) => t.id.equals(prodId))).getSingleOrNull();
      if (currentProd != null) {
        await (_db.update(_db.localProductsTable)..where((t) => t.id.equals(prodId))).write(
          LocalProductsTableCompanion(
            currentStock: Value(currentProd.currentStock - qty),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }

    // 3. Queue Outbox record for guaranteed delivery when reconnected
    final payloadJson = jsonEncode({
      'clientInvoiceRef': clientInvoiceRef,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'discountAmount': discountAmount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'items': items,
    });

    final outboxId = await _db.into(_db.syncOutboxTable).insert(
      SyncOutboxTableCompanion(
        idempotencyKey: Value(idempotencyKey),
        clientMutationId: Value(clientInvoiceRef),
        mutationType: const Value('CREATE_SALE'),
        entityType: const Value('Sale'),
        localEntityId: Value(localSaleId),
        payloadJson: Value(payloadJson),
        status: const Value(OutboxStatus.pending),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 4. If connected to API, attempt fast online mutation (max 2 seconds timeout)
    String authoritativeInvoiceNumber = clientInvoiceRef;
    bool isSynced = false;

    if (!_isOffline) {
      try {
        const saleMutation = r'''
          mutation CreateSale($input: CreateSaleInput!) {
            createSale(input: $input) {
              id
              invoiceNumber
              clientInvoiceRef
              grandTotal
              paidAmount
              paymentStatus
            }
          }
        ''';

        final result = await _client.mutate(
          MutationOptions(
            document: gql(saleMutation),
            variables: {
              'input': {
                'idempotencyKey': idempotencyKey,
                'clientInvoiceRef': clientInvoiceRef,
                'customerId': customerId,
                'customerName': customerName,
                'customerPhone': customerPhone,
                'discountAmount': discountAmount,
                'paidAmount': paidAmount,
                'paymentMethod': paymentMethod,
                'items': items.map((it) => {
                  'productId': it['productId'],
                  'quantity': (it['quantity'] as num).toDouble(),
                  'unitPrice': (it['unitPrice'] as num).toDouble(),
                  'taxRate': (it['taxRate'] as num?)?.toDouble() ?? 0.0,
                  'discountAmount': (it['discountAmount'] as num?)?.toDouble() ?? 0.0,
                }).toList(),
              }
            },
          ),
        ).timeout(const Duration(seconds: 2));

        if (!result.hasException && result.data?['createSale'] != null) {
          final saleData = result.data!['createSale'];
          authoritativeInvoiceNumber = saleData['invoiceNumber'] as String;
          final serverId = saleData['id'] as String;
          isSynced = true;

          // Update local sale record with authoritative invoice number and server ID
          await (_db.update(_db.localSalesTable)..where((t) => t.id.equals(localSaleId))).write(
            LocalSalesTableCompanion(
              serverId: Value(serverId),
              invoiceNumber: Value(authoritativeInvoiceNumber),
              isSynced: const Value(true),
            ),
          );

          // Mark outbox entry completed
          await (_db.update(_db.syncOutboxTable)..where((t) => t.id.equals(outboxId))).write(
            SyncOutboxTableCompanion(
              status: const Value(OutboxStatus.completed),
              lastAttemptedAt: Value(DateTime.now()),
            ),
          );
        } else {
          // Disconnected or API error: remain offline safely
          _isOffline = true;
          _statusController.add(SyncEngineStatus.offline);
        }
      } catch (_) {
        // Disconnected or API timeout: proceed in offline mode safely
        _isOffline = true;
        _statusController.add(SyncEngineStatus.offline);
      }
    }

    return {
      'invoiceNumber': authoritativeInvoiceNumber,
      'isSynced': isSynced,
      'grandTotal': grandTotal,
      'paidAmount': paidAmount,
      'clientInvoiceRef': clientInvoiceRef,
    };
  }

  /// Creates a Product offline-first, inserts into local Drift database, and syncs to cloud
  Future<LocalProductsTableData> createProduct({
    required String name,
    String sku = '',
    String barcode = '',
    double sellingPrice = 0.0,
    double costPrice = 0.0,
    double initialStock = 100.0,
  }) async {
    const uuid = Uuid();
    final localId = uuid.v4();
    final idempotencyKey = uuid.v4();
    final generatedSku = sku.isNotEmpty ? sku : 'SKU-${localId.substring(0, 8).toUpperCase()}';

    // 1. Insert into local Drift LocalProductsTable
    final companion = LocalProductsTableCompanion(
      id: Value(localId),
      serverId: const Value(null),
      businessId: const Value('demo-retail'),
      name: Value(name),
      sku: Value(generatedSku),
      barcode: Value(barcode),
      sellingPrice: Value(sellingPrice),
      costPrice: Value(costPrice),
      currentStock: Value(initialStock),
      isSynced: const Value(false),
      updatedAt: Value(DateTime.now()),
    );
    await _db.into(_db.localProductsTable).insert(companion);

    // 2. Queue in Outbox table
    final payloadJson = jsonEncode({
      'name': name,
      'sku': generatedSku,
      'barcode': barcode,
      'sellingPrice': sellingPrice,
      'costPrice': costPrice,
      'initialStock': initialStock,
    });

    final outboxId = await _db.into(_db.syncOutboxTable).insert(
      SyncOutboxTableCompanion(
        idempotencyKey: Value(idempotencyKey),
        clientMutationId: Value(localId),
        mutationType: const Value('CREATE_PRODUCT'),
        entityType: const Value('Product'),
        localEntityId: Value(localId),
        payloadJson: Value(payloadJson),
        status: const Value(OutboxStatus.pending),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 3. Attempt immediate online creation if connected
    if (!_isOffline) {
      try {
        const prodMutation = r'''
          mutation CreateProduct($input: CreateProductInput!) {
            createProduct(input: $input) {
              id
              name
              sku
              barcode
              sellingPrice
              costPrice
            }
          }
        ''';

        final result = await _client.mutate(
          MutationOptions(
            document: gql(prodMutation),
            variables: {
              'input': {
                'name': name,
                'sku': generatedSku,
                'barcode': barcode,
                'sellingPrice': sellingPrice,
                'costPrice': costPrice,
              }
            },
          ),
        ).timeout(const Duration(seconds: 2));

        if (!result.hasException && result.data?['createProduct'] != null) {
          final serverProd = result.data!['createProduct'];
          final serverId = serverProd['id'] as String;
          // Mark as synced locally
          await (_db.update(_db.localProductsTable)..where((t) => t.id.equals(localId))).write(
            LocalProductsTableCompanion(
              serverId: Value(serverId),
              isSynced: const Value(true),
            ),
          );
          // Mark outbox completed
          await (_db.update(_db.syncOutboxTable)..where((t) => t.id.equals(outboxId))).write(
            const SyncOutboxTableCompanion(
              status: Value(OutboxStatus.completed),
            ),
          );
        } else {
          _isOffline = true;
          _statusController.add(SyncEngineStatus.offline);
        }
      } catch (_) {
        _isOffline = true;
        _statusController.add(SyncEngineStatus.offline);
      }
    }

    final saved = await (_db.select(_db.localProductsTable)..where((t) => t.id.equals(localId))).getSingle();
    return saved;
  }

  /// Creates a Customer offline-first, inserts into local Drift database, and syncs to cloud
  Future<LocalCustomersTableData> createCustomer({
    required String name,
    String phone = '',
    String email = '',
    double initialBalance = 0.0,
    double creditLimit = 0.0,
  }) async {
    const uuid = Uuid();
    final localId = uuid.v4();
    final idempotencyKey = uuid.v4();

    // 1. Insert into local Drift LocalCustomersTable
    final companion = LocalCustomersTableCompanion(
      id: Value(localId),
      serverId: const Value(null),
      businessId: const Value('demo-retail'),
      name: Value(name),
      phone: Value(phone),
      email: Value(email),
      currentBalance: Value(initialBalance),
      isSynced: const Value(false),
      updatedAt: Value(DateTime.now()),
    );
    await _db.into(_db.localCustomersTable).insert(companion);

    // 2. Queue in Outbox table
    final payloadJson = jsonEncode({
      'name': name,
      'phone': phone,
      'email': email,
      'initialBalance': initialBalance,
      'creditLimit': creditLimit,
    });

    final outboxId = await _db.into(_db.syncOutboxTable).insert(
      SyncOutboxTableCompanion(
        idempotencyKey: Value(idempotencyKey),
        clientMutationId: Value(localId),
        mutationType: const Value('CREATE_CUSTOMER'),
        entityType: const Value('Customer'),
        localEntityId: Value(localId),
        payloadJson: Value(payloadJson),
        status: const Value(OutboxStatus.pending),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 3. Attempt immediate online creation if connected
    if (!_isOffline) {
      try {
        const custMutation = r'''
          mutation CreateCustomer($input: CreateCustomerInput!) {
            createCustomer(input: $input) {
              id
              name
              phone
              email
              currentBalance
              creditLimit
            }
          }
        ''';

        final result = await _client.mutate(
          MutationOptions(
            document: gql(custMutation),
            variables: {
              'input': {
                'name': name,
                'phone': phone,
                'email': email,
                'initialBalance': initialBalance,
                'creditLimit': creditLimit,
              }
            },
          ),
        ).timeout(const Duration(seconds: 2));

        if (!result.hasException && result.data?['createCustomer'] != null) {
          final serverCust = result.data!['createCustomer'];
          final serverId = serverCust['id'] as String;
          // Mark as synced locally
          await (_db.update(_db.localCustomersTable)..where((t) => t.id.equals(localId))).write(
            LocalCustomersTableCompanion(
              serverId: Value(serverId),
              isSynced: const Value(true),
            ),
          );
          // Mark outbox completed
          await (_db.update(_db.syncOutboxTable)..where((t) => t.id.equals(outboxId))).write(
            const SyncOutboxTableCompanion(
              status: Value(OutboxStatus.completed),
            ),
          );
        } else {
          _isOffline = true;
          _statusController.add(SyncEngineStatus.offline);
        }
      } catch (_) {
        _isOffline = true;
        _statusController.add(SyncEngineStatus.offline);
      }
    }

    final saved = await (_db.select(_db.localCustomersTable)..where((t) => t.id.equals(localId))).getSingle();
    return saved;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
