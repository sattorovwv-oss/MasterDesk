import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/entities.dart';

class AppDatabase {
  final Uuid _uuid = const Uuid();
  late Database _db;

  Database get raw => _db;

  Future<void> open() async {
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'masterdesk.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY CHECK(id = 1),
        name TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'TJS',
        locale_code TEXT NOT NULL DEFAULT 'ru',
        theme_mode TEXT NOT NULL DEFAULT 'system',
        onboarding_done INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.insert('settings', {'id': 1});
    await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.insert('meta', {'key': 'next_order_number', 'value': '1'});
    await db.execute('''
      CREATE TABLE customers(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        normalized_phone TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(normalized_phone)');
    await db.execute('''
      CREATE TABLE employees(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        contact TEXT NOT NULL DEFAULT '',
        color_value INTEGER NOT NULL DEFAULT 4280391411,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE orders(
        id TEXT PRIMARY KEY,
        order_number INTEGER NOT NULL UNIQUE,
        customer_id TEXT NOT NULL REFERENCES customers(id),
        employee_id TEXT REFERENCES employees(id),
        device_category TEXT NOT NULL,
        device_name TEXT NOT NULL,
        problem TEXT NOT NULL,
        condition_note TEXT NOT NULL DEFAULT '',
        serial_number TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'normal',
        deadline_utc TEXT,
        ready_at_utc TEXT,
        delivered_at_utc TEXT,
        total_minor INTEGER NOT NULL DEFAULT 0,
        discount_minor INTEGER NOT NULL DEFAULT 0,
        paid_minor INTEGER NOT NULL DEFAULT 0,
        internal_note TEXT NOT NULL DEFAULT '',
        client_comment TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL,
        updated_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_customer ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_deadline ON orders(deadline_utc)');
    await db.execute('''
      CREATE TABLE order_items(
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        reference_id TEXT,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
        cost_minor INTEGER NOT NULL DEFAULT 0,
        stock_consumed INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE payments(
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL REFERENCES orders(id),
        kind TEXT NOT NULL CHECK(kind IN ('payment','refund')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        method TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_payments_date ON payments(created_at_utc)');
    await db.execute('''
      CREATE TABLE parts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT NOT NULL DEFAULT '',
        compatibility TEXT NOT NULL DEFAULT '',
        quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
        minimum_quantity INTEGER NOT NULL DEFAULT 0 CHECK(minimum_quantity >= 0),
        purchase_price_minor INTEGER NOT NULL DEFAULT 0,
        selling_price_minor INTEGER NOT NULL DEFAULT 0,
        location TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_parts_sku ON parts(sku)');
    await db.execute('''
      CREATE TABLE stock_movements(
        id TEXT PRIMARY KEY,
        part_id TEXT NOT NULL REFERENCES parts(id),
        order_id TEXT REFERENCES orders(id),
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost_minor INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        command_key TEXT UNIQUE,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE services(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        price_minor INTEGER NOT NULL DEFAULT 0,
        duration_minutes INTEGER,
        note TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        order_id TEXT REFERENCES orders(id),
        employee_id TEXT REFERENCES employees(id),
        due_at_utc TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE expenses(
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        note TEXT NOT NULL DEFAULT '',
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE order_events(
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        description_ru TEXT NOT NULL,
        description_en TEXT NOT NULL,
        created_at_utc TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_events_order ON order_events(order_id, created_at_utc)');
  }

  Future<WorkshopSettings> getSettings() async {
    final row = (await _db.query('settings', where: 'id = 1')).single;
    return WorkshopSettings(
      name: row['name']! as String,
      phone: row['phone']! as String,
      address: row['address']! as String,
      currency: row['currency']! as String,
      localeCode: row['locale_code']! as String,
      themeMode: row['theme_mode']! as String,
      onboardingDone: row['onboarding_done'] == 1,
    );
  }

  Future<void> saveSettings({
    String? name,
    String? phone,
    String? address,
    String? currency,
    String? localeCode,
    String? themeMode,
    bool? onboardingDone,
  }) async {
    final values = <String, Object?>{};
    if (name != null) values['name'] = name;
    if (phone != null) values['phone'] = phone;
    if (address != null) values['address'] = address;
    if (currency != null) values['currency'] = currency;
    if (localeCode != null) values['locale_code'] = localeCode;
    if (themeMode != null) values['theme_mode'] = themeMode;
    if (onboardingDone != null) values['onboarding_done'] = onboardingDone ? 1 : 0;
    if (values.isNotEmpty) {
      await _db.update('settings', values, where: 'id = 1');
    }
  }

  String normalizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  Future<List<Customer>> getCustomers({String query = ''}) async {
    final normalized = normalizePhone(query);
    final rows = await _db.rawQuery('''
      SELECT c.*,
        COUNT(o.id) AS order_count,
        COALESCE(SUM(CASE WHEN o.total_minor - o.paid_minor > 0
          THEN o.total_minor - o.paid_minor ELSE 0 END), 0) AS debt_minor
      FROM customers c
      LEFT JOIN orders o ON o.customer_id = c.id AND o.archived = 0
      WHERE c.archived = 0 AND (
        ? = '' OR LOWER(c.name) LIKE ? OR c.normalized_phone LIKE ?
      )
      GROUP BY c.id
      ORDER BY c.name COLLATE NOCASE
    ''', [query, '%${query.toLowerCase()}%', '%$normalized%']);
    return rows.map(Customer.fromMap).toList();
  }

  Future<String> createCustomer({
    required String name,
    required String phone,
    String note = '',
  }) async {
    final id = _uuid.v4();
    await _db.insert('customers', {
      'id': id,
      'name': name.trim(),
      'phone': phone.trim(),
      'normalized_phone': normalizePhone(phone),
      'note': note.trim(),
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<List<RepairOrder>> getOrders({
    String query = '',
    String filter = 'all',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    var extra = '';
    final args = <Object?>[];
    if (filter == 'active') {
      extra = "AND o.status NOT IN ('ready','delivered','cancelled')";
    } else if (filter == 'ready') {
      extra = "AND o.status = 'ready'";
    } else if (filter == 'overdue') {
      extra = "AND o.deadline_utc IS NOT NULL AND o.deadline_utc < ? AND o.status NOT IN ('ready','delivered','cancelled')";
      args.add(now);
    } else if (filter == 'debt') {
      extra = 'AND o.total_minor > o.paid_minor';
    }
    final like = '%${query.toLowerCase()}%';
    final normalized = normalizePhone(query);
    args.addAll([query, like, like, '%$normalized%', like]);
    final rows = await _db.rawQuery('''
      SELECT o.*, c.name AS customer_name, c.phone AS customer_phone
      FROM orders o JOIN customers c ON c.id = o.customer_id
      WHERE o.archived = 0 $extra AND (
        ? = '' OR LOWER(o.device_name) LIKE ? OR LOWER(c.name) LIKE ?
        OR c.normalized_phone LIKE ? OR LOWER('MD-' || printf('%06d', o.order_number)) LIKE ?
      )
      ORDER BY o.created_at_utc DESC
    ''', args);
    return rows.map(RepairOrder.fromMap).toList();
  }

  Future<RepairOrder?> getOrder(String id) async {
    final rows = await _db.rawQuery('''
      SELECT o.*, c.name AS customer_name, c.phone AS customer_phone
      FROM orders o JOIN customers c ON c.id = o.customer_id
      WHERE o.id = ?
    ''', [id]);
    return rows.isEmpty ? null : RepairOrder.fromMap(rows.first);
  }

  Future<String> createOrder({
    required String customerId,
    required String deviceCategory,
    required String deviceName,
    required String problem,
    String conditionNote = '',
    String serialNumber = '',
    String priority = 'normal',
    DateTime? deadline,
    int estimateMinor = 0,
    int depositMinor = 0,
    String paymentMethod = 'cash',
    String internalNote = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      final meta = (await txn.query(
        'meta',
        where: 'key = ?',
        whereArgs: ['next_order_number'],
      )).single;
      final number = int.parse(meta['value']! as String);
      await txn.update(
        'meta',
        {'value': (number + 1).toString()},
        where: 'key = ?',
        whereArgs: ['next_order_number'],
      );
      await txn.insert('orders', {
        'id': id,
        'order_number': number,
        'customer_id': customerId,
        'device_category': deviceCategory,
        'device_name': deviceName.trim(),
        'problem': problem.trim(),
        'condition_note': conditionNote.trim(),
        'serial_number': serialNumber.trim(),
        'status': 'received',
        'priority': priority,
        'deadline_utc': deadline?.toUtc().toIso8601String(),
        'total_minor': estimateMinor,
        'paid_minor': depositMinor,
        'internal_note': internalNote.trim(),
        'created_at_utc': now,
        'updated_at_utc': now,
      });
      if (depositMinor > 0) {
        await txn.insert('payments', {
          'id': _uuid.v4(),
          'order_id': id,
          'kind': 'payment',
          'amount_minor': depositMinor,
          'method': paymentMethod,
          'note': 'Deposit',
          'created_at_utc': now,
        });
      }
      await _addEventTxn(
        txn,
        orderId: id,
        type: 'created',
        ru: 'Заказ создан. Устройство принято.',
        en: 'Order created. Device received.',
        time: now,
      );
    });
    return id;
  }

  Future<void> addOrderItem({
    required String orderId,
    required String name,
    required String type,
    required int quantity,
    required int unitPriceMinor,
    int costMinor = 0,
    String? referenceId,
  }) async {
    if (quantity <= 0 || unitPriceMinor < 0) {
      throw ArgumentError('Invalid item values');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.insert('order_items', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'type': type,
        'reference_id': referenceId,
        'name': name.trim(),
        'quantity': quantity,
        'unit_price_minor': unitPriceMinor,
        'cost_minor': costMinor,
        'created_at_utc': now,
      });
      await _recalculateTotalTxn(txn, orderId);
      await _addEventTxn(
        txn,
        orderId: orderId,
        type: 'item_added',
        ru: 'Добавлена позиция: ${name.trim()}',
        en: 'Item added: ${name.trim()}',
        time: now,
      );
    });
  }

  Future<List<Map<String, Object?>>> getOrderItems(String orderId) =>
      _db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);

  Future<void> _recalculateTotalTxn(Transaction txn, String orderId) async {
    final row = (await txn.rawQuery(
      'SELECT COALESCE(SUM(quantity * unit_price_minor), 0) AS subtotal FROM order_items WHERE order_id = ?',
      [orderId],
    )).single;
    final order = (await txn.query('orders', where: 'id = ?', whereArgs: [orderId])).single;
    final subtotal = row['subtotal']! as int;
    final discount = (order['discount_minor']! as int).clamp(0, subtotal) as int;
    await txn.update(
      'orders',
      {
        'total_minor': subtotal - discount,
        'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<void> addPayment({
    required String orderId,
    required int amountMinor,
    required String method,
    String note = '',
    bool refund = false,
  }) async {
    if (amountMinor <= 0) throw ArgumentError('Amount must be positive');
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      final order = (await txn.query('orders', where: 'id = ?', whereArgs: [orderId])).single;
      final current = order['paid_minor']! as int;
      if (refund && amountMinor > current) {
        throw StateError('Refund exceeds received payments');
      }
      final next = refund ? current - amountMinor : current + amountMinor;
      await txn.insert('payments', {
        'id': _uuid.v4(),
        'order_id': orderId,
        'kind': refund ? 'refund' : 'payment',
        'amount_minor': amountMinor,
        'method': method,
        'note': note.trim(),
        'created_at_utc': now,
      });
      await txn.update(
        'orders',
        {'paid_minor': next, 'updated_at_utc': now},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await _addEventTxn(
        txn,
        orderId: orderId,
        type: refund ? 'refund' : 'payment',
        ru: refund ? 'Оформлен возврат' : 'Добавлена оплата',
        en: refund ? 'Refund recorded' : 'Payment recorded',
        time: now,
      );
    });
  }

  Future<List<Map<String, Object?>>> getPayments(String orderId) => _db.query(
        'payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at_utc DESC',
      );

  Future<void> advanceOrderStatus(String orderId) async {
    const next = {
      'received': 'diagnosing',
      'diagnosing': 'awaiting_approval',
      'awaiting_approval': 'in_progress',
      'awaiting_parts': 'in_progress',
      'in_progress': 'ready',
      'ready': 'delivered',
    };
    final order = await getOrder(orderId);
    if (order == null || !next.containsKey(order.status)) return;
    final nextStatus = next[order.status]!;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'status': nextStatus,
          if (nextStatus == 'ready') 'ready_at_utc': now,
          if (nextStatus == 'delivered') 'delivered_at_utc': now,
          'updated_at_utc': now,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await _addEventTxn(
        txn,
        orderId: orderId,
        type: 'status',
        ru: 'Статус изменён: ${order.status} → $nextStatus',
        en: 'Status changed: ${order.status} → $nextStatus',
        time: now,
      );
    });
  }

  Future<List<OrderEvent>> getEvents(String orderId) async {
    final rows = await _db.query(
      'order_events',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at_utc DESC',
    );
    return rows.map(OrderEvent.fromMap).toList();
  }

  Future<void> _addEventTxn(
    Transaction txn, {
    required String orderId,
    required String type,
    required String ru,
    required String en,
    required String time,
  }) async {
    await txn.insert('order_events', {
      'id': _uuid.v4(),
      'order_id': orderId,
      'type': type,
      'description_ru': ru,
      'description_en': en,
      'created_at_utc': time,
    });
  }

  Future<List<Part>> getParts({String query = '', String filter = 'all'}) async {
    var extra = '';
    if (filter == 'low') extra = 'AND quantity <= minimum_quantity';
    if (filter == 'empty') extra = 'AND quantity = 0';
    final like = '%${query.toLowerCase()}%';
    final rows = await _db.rawQuery('''
      SELECT * FROM parts
      WHERE archived = 0 $extra AND (
        ? = '' OR LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR LOWER(compatibility) LIKE ?
      ) ORDER BY name COLLATE NOCASE
    ''', [query, like, like, like]);
    return rows.map(Part.fromMap).toList();
  }

  Future<String> createPart({
    required String name,
    String sku = '',
    String compatibility = '',
    int quantity = 0,
    int minimumQuantity = 0,
    int purchasePriceMinor = 0,
    int sellingPriceMinor = 0,
    String location = '',
  }) async {
    if (quantity < 0 || minimumQuantity < 0) throw ArgumentError('Invalid stock');
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.insert('parts', {
        'id': id,
        'name': name.trim(),
        'sku': sku.trim(),
        'compatibility': compatibility.trim(),
        'quantity': quantity,
        'minimum_quantity': minimumQuantity,
        'purchase_price_minor': purchasePriceMinor,
        'selling_price_minor': sellingPriceMinor,
        'location': location.trim(),
        'created_at_utc': now,
      });
      if (quantity > 0) {
        await txn.insert('stock_movements', {
          'id': _uuid.v4(),
          'part_id': id,
          'type': 'receipt',
          'quantity': quantity,
          'unit_cost_minor': purchasePriceMinor,
          'note': 'Initial stock',
          'created_at_utc': now,
        });
      }
    });
    return id;
  }

  Future<void> adjustStock({
    required String partId,
    required int delta,
    required String type,
    String note = '',
    String? commandKey,
  }) async {
    if (delta == 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      if (commandKey != null) {
        final duplicate = await txn.query(
          'stock_movements',
          where: 'command_key = ?',
          whereArgs: [commandKey],
          limit: 1,
        );
        if (duplicate.isNotEmpty) return;
      }
      final part = (await txn.query('parts', where: 'id = ?', whereArgs: [partId])).single;
      final next = (part['quantity']! as int) + delta;
      if (next < 0) throw StateError('Not enough stock');
      await txn.update('parts', {'quantity': next}, where: 'id = ?', whereArgs: [partId]);
      await txn.insert('stock_movements', {
        'id': _uuid.v4(),
        'part_id': partId,
        'type': type,
        'quantity': delta,
        'unit_cost_minor': part['purchase_price_minor']! as int,
        'note': note.trim(),
        'command_key': commandKey,
        'created_at_utc': now,
      });
    });
  }

  Future<Map<String, int>> getDashboard() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    final active = Sqflite.firstIntValue(await _db.rawQuery(
          "SELECT COUNT(*) FROM orders WHERE archived = 0 AND status NOT IN ('ready','delivered','cancelled')",
        )) ??
        0;
    final ready = Sqflite.firstIntValue(await _db.rawQuery(
          "SELECT COUNT(*) FROM orders WHERE archived = 0 AND status = 'ready'",
        )) ??
        0;
    final overdue = Sqflite.firstIntValue(await _db.rawQuery(
          "SELECT COUNT(*) FROM orders WHERE archived = 0 AND deadline_utc < ? AND status NOT IN ('ready','delivered','cancelled')",
          [DateTime.now().toUtc().toIso8601String()],
        )) ??
        0;
    final moneyRows = await _db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN kind = 'payment' THEN amount_minor ELSE -amount_minor END), 0) AS value
      FROM payments WHERE created_at_utc >= ? AND created_at_utc < ?
    ''', [start, end]);
    return {
      'active': active,
      'ready': ready,
      'overdue': overdue,
      'todayMinor': moneyRows.first['value']! as int,
    };
  }

  static const List<String> _backupTables = [
    'customers',
    'employees',
    'orders',
    'order_items',
    'payments',
    'parts',
    'stock_movements',
    'services',
    'tasks',
    'expenses',
    'order_events',
  ];

  Future<Map<String, Object?>> exportSnapshot() async {
    final data = <String, Object?>{
      'format': 'masterdesk-backup',
      'version': 1,
      'created_at_utc': DateTime.now().toUtc().toIso8601String(),
      'settings': await _db.query('settings'),
    };
    for (final table in _backupTables) {
      data[table] = await _db.query(table);
    }
    return data;
  }

  Future<void> restoreSnapshot(Map<String, Object?> snapshot) async {
    if (snapshot['format'] != 'masterdesk-backup' || snapshot['version'] != 1) {
      throw const FormatException('Unsupported backup');
    }
    for (final table in _backupTables) {
      if (snapshot[table] is! List) throw const FormatException('Incomplete backup');
    }
    await _db.transaction((txn) async {
      for (final table in _backupTables.reversed) {
        await txn.delete(table);
      }
      final settings = (snapshot['settings']! as List).cast<Map>();
      if (settings.isNotEmpty) {
        await txn.update(
          'settings',
          settings.first.cast<String, Object?>()..remove('id'),
          where: 'id = 1',
        );
      }
      for (final table in _backupTables) {
        for (final rawRow in snapshot[table]! as List) {
          await txn.insert(table, (rawRow as Map).cast<String, Object?>());
        }
      }
      final maxRows = await txn.rawQuery('SELECT COALESCE(MAX(order_number), 0) AS value FROM orders');
      final next = (maxRows.first['value']! as int) + 1;
      await txn.update('meta', {'value': next.toString()}, where: 'key = ?', whereArgs: ['next_order_number']);
    });
  }

  Future<String> exportSnapshotJson() async => jsonEncode(await exportSnapshot());
}
