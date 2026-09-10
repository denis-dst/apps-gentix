import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalGateDataService {
  static final LocalGateDataService _instance = LocalGateDataService._internal();
  factory LocalGateDataService() => _instance;
  LocalGateDataService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gentix_gate_local.db');

    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Recreate tables that hold cache data (safe to drop and download again)
          await db.execute('DROP TABLE IF EXISTS local_gate_tickets');
          await db.execute('DROP TABLE IF EXISTS local_gate_gates');
          
          await db.execute('''
            CREATE TABLE local_gate_tickets (
              id INTEGER PRIMARY KEY,
              ticket_id INTEGER NOT NULL,
              event_id INTEGER NOT NULL,
              tenant_id INTEGER NOT NULL,
              ticket_category_id INTEGER NOT NULL,
              ticket_code TEXT NOT NULL,
              wristband_qr TEXT,
              category_name TEXT,
              customer_name TEXT,
              customer_email TEXT,
              custom_question_label TEXT,
              custom_question_answer TEXT,
              reference_no TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE local_gate_gates (
              id INTEGER PRIMARY KEY,
              gate_id INTEGER NOT NULL,
              event_id INTEGER NOT NULL,
              gate_name TEXT NOT NULL,
              allowed_category_ids TEXT
            )
          ''');
          
          // Ensure logs table exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_gate_scan_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              offline_id TEXT NOT NULL,
              ticket_id INTEGER NOT NULL,
              event_id INTEGER NOT NULL,
              tenant_id INTEGER NOT NULL,
              gate_name TEXT NOT NULL,
              type TEXT NOT NULL,
              scanned_at TEXT NOT NULL,
              device_id TEXT,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_gate_events (
              id INTEGER PRIMARY KEY,
              event_id INTEGER NOT NULL UNIQUE,
              tenant_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              venue TEXT,
              event_start_date TEXT,
              security_code TEXT,
              downloaded_at TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE local_gate_tickets (
        id INTEGER PRIMARY KEY,
        ticket_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        tenant_id INTEGER NOT NULL,
        ticket_category_id INTEGER NOT NULL,
        ticket_code TEXT NOT NULL,
        wristband_qr TEXT,
        category_name TEXT,
        customer_name TEXT,
        customer_email TEXT,
        custom_question_label TEXT,
        custom_question_answer TEXT,
        reference_no TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_gate_gates (
        id INTEGER PRIMARY KEY,
        gate_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        gate_name TEXT NOT NULL,
        allowed_category_ids TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_gate_scan_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        offline_id TEXT NOT NULL,
        ticket_id INTEGER NOT NULL,
        event_id INTEGER NOT NULL,
        tenant_id INTEGER NOT NULL,
        gate_name TEXT NOT NULL,
        type TEXT NOT NULL,
        scanned_at TEXT NOT NULL,
        device_id TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_gate_events (
        id INTEGER PRIMARY KEY,
        event_id INTEGER NOT NULL UNIQUE,
        tenant_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        venue TEXT,
        event_start_date TEXT,
        security_code TEXT,
        downloaded_at TEXT
      )
    ''');
  }

  Future<void> replaceEventData({
    required int eventId,
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> gates,
  }) async {
    final db = await database;
    final batch = db.batch();

    batch.delete('local_gate_tickets', where: 'event_id = ?', whereArgs: [eventId]);
    batch.delete('local_gate_gates', where: 'event_id = ?', whereArgs: [eventId]);

    for (final ticket in tickets) {
      batch.insert('local_gate_tickets', ticket);
    }

    for (final gate in gates) {
      batch.insert('local_gate_gates', gate);
    }

    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> findTicket(String code, int eventId) async {
    final db = await database;
    final rows = await db.query(
      'local_gate_tickets',
      where: 'event_id = ? AND (ticket_code = ? OR wristband_qr = ?)',
      whereArgs: [eventId, code, code],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<int>> getAllowedCategoryIds({
    required int eventId,
    required int gateId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'local_gate_gates',
      where: 'event_id = ? AND gate_id = ?',
      whereArgs: [eventId, gateId],
      limit: 1,
    );

    if (rows.isEmpty) return [];
    final raw = (rows.first['allowed_category_ids'] as String?) ?? '';
    if (raw.isEmpty) return [];

    return raw
        .split(',')
        .where((item) => item.trim().isNotEmpty)
        .map(int.parse)
        .toList();
  }

  Future<Map<String, dynamic>?> getLastScanLog(int ticketId) async {
    final db = await database;
    final rows = await db.query(
      'local_gate_scan_logs',
      where: 'ticket_id = ?',
      whereArgs: [ticketId],
      orderBy: 'scanned_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> addScanLog(Map<String, dynamic> log) async {
    final db = await database;
    await db.insert('local_gate_scan_logs', log);
  }

  Future<List<Map<String, dynamic>>> getPendingScanLogs() async {
    final db = await database;
    return db.query(
      'local_gate_scan_logs',
      where: 'synced = 0',
      orderBy: 'scanned_at ASC',
    );
  }

  Future<void> markLogsSynced(List<String> offlineIds) async {
    if (offlineIds.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(offlineIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE local_gate_scan_logs SET synced = 1 WHERE offline_id IN ($placeholders)',
      offlineIds,
    );
  }

  Future<List<Map<String, dynamic>>> getTicketsByReference(String referenceNo) async {
    final db = await database;
    return db.query(
      'local_gate_tickets',
      where: 'reference_no = ?',
      whereArgs: [referenceNo],
    );
  }

  Future<Map<String, dynamic>?> findTicketById(int ticketId) async {
    final db = await database;
    final rows = await db.query(
      'local_gate_tickets',
      where: 'ticket_id = ?',
      whereArgs: [ticketId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> getLocalTicketCount(int eventId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM local_gate_tickets WHERE event_id = ?',
      [eventId],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> saveEvent(Map<String, dynamic> event) async {
    final db = await database;
    await db.insert(
      'local_gate_events',
      event,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLocalEvents() async {
    final db = await database;
    return db.query('local_gate_events', orderBy: 'event_start_date DESC');
  }

  Future<Map<String, dynamic>?> getLocalEvent(int eventId) async {
    final db = await database;
    final rows = await db.query(
      'local_gate_events',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getLocalGates(int eventId) async {
    final db = await database;
    return db.query(
      'local_gate_gates',
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  Future<int> getPendingLogCount([int? eventId]) async {
    final db = await database;
    final String sql = eventId != null
        ? 'SELECT COUNT(*) as total FROM local_gate_scan_logs WHERE synced = 0 AND event_id = ?'
        : 'SELECT COUNT(*) as total FROM local_gate_scan_logs WHERE synced = 0';
    final List<dynamic> args = eventId != null ? [eventId] : [];
    final result = await db.rawQuery(sql, args);
    return (result.first['total'] as int?) ?? 0;
  }
}
