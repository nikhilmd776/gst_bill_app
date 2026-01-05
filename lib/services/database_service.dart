import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class InvoiceDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gst_billing.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    // Create invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_address TEXT,
        total_amount REAL NOT NULL,
        gst_amount REAL NOT NULL,
        invoice_type TEXT NOT NULL,
        created_date TEXT NOT NULL,
        pdf_path TEXT
      )
    ''');

    // Create invoice_items table
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        hsn_code TEXT,
        quantity INTEGER NOT NULL,
        rate REAL NOT NULL,
        gst_percent REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_name)');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices(created_date)');
    await db.execute('CREATE INDEX idx_invoices_type ON invoices(invoice_type)');
    await db.execute('CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id)');
  }

  static Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here in the future
    if (oldVersion < newVersion) {
      // Migration logic
    }
  }

  // Invoice CRUD operations
  static Future<int> insertInvoice(Invoice invoice) async {
    final db = await database;
    return await db.insert('invoices', invoice.toMap());
  }

  static Future<List<Invoice>> getAllInvoices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      orderBy: 'created_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  static Future<Invoice?> getInvoice(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Invoice.fromMap(maps.first);
  }

  static Future<int> updateInvoice(Invoice invoice) async {
    final db = await database;
    return await db.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
  }

  static Future<int> deleteInvoice(int id) async {
    final db = await database;
    return await db.delete(
      'invoices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Invoice search and filter operations
  static Future<List<Invoice>> searchInvoicesByCustomer(String customerName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'customer_name LIKE ?',
      whereArgs: ['%$customerName%'],
      orderBy: 'created_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  static Future<List<Invoice>> getInvoicesByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'created_date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'created_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  static Future<List<Invoice>> getInvoicesByType(String invoiceType) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoices',
      where: 'invoice_type = ?',
      whereArgs: [invoiceType],
      orderBy: 'created_date DESC',
    );
    return List.generate(maps.length, (i) => Invoice.fromMap(maps[i]));
  }

  // Invoice statistics
  static Future<double> getTotalSales({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE created_date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM invoices $whereClause',
      whereArgs,
    );

    return result.first['total'] as double? ?? 0.0;
  }

  static Future<int> getInvoiceCount({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE created_date BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM invoices $whereClause',
      whereArgs,
    );

    return result.first['count'] as int? ?? 0;
  }

  // InvoiceItem CRUD operations
  static Future<int> insertInvoiceItem(InvoiceItem item) async {
    final db = await database;
    return await db.insert('invoice_items', item.toMap());
  }

  static Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return List.generate(maps.length, (i) => InvoiceItem.fromMap(maps[i]));
  }

  static Future<int> updateInvoiceItem(InvoiceItem item) async {
    final db = await database;
    return await db.update(
      'invoice_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  static Future<int> deleteInvoiceItem(int id) async {
    final db = await database;
    return await db.delete(
      'invoice_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Save complete invoice with items
  static Future<int> saveCompleteInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Insert invoice
      final invoiceId = await txn.insert('invoices', invoice.toMap());

      // Insert invoice items
      for (final item in items) {
        final itemMap = item.copyWith(invoiceId: invoiceId).toMap();
        await txn.insert('invoice_items', itemMap);
      }

      return invoiceId;
    });
  }

  // Get complete invoice with items
  static Future<Map<String, dynamic>?> getCompleteInvoice(int invoiceId) async {
    final db = await database;

    // Get invoice
    final invoiceMaps = await db.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );

    if (invoiceMaps.isEmpty) return null;

    final invoice = Invoice.fromMap(invoiceMaps.first);

    // Get invoice items
    final itemMaps = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    final items = itemMaps.map((map) => InvoiceItem.fromMap(map)).toList();

    return {
      'invoice': invoice,
      'items': items,
    };
  }

  // Database maintenance
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('invoice_items');
    await db.delete('invoices');
  }

  static Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}