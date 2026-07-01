import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DBHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'truck_parts_pro.db');
    
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reference TEXT UNIQUE,
            name TEXT,
            buying_price REAL,
            selling_price REAL,
            quantity INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER,
            product_name TEXT,
            quantity INTEGER,
            buying_price REAL,
            selling_price REAL,
            date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            debt REAL DEFAULT 0.0
          )
        ''');
        await db.execute('''
          CREATE TABLE customer_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER,
            product_name TEXT,
            quantity INTEGER,
            price REAL,
            date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE companies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            total_debt REAL DEFAULT 0.0
          )
        ''');
        await db.execute('''
          CREATE TABLE company_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER,
            product_name TEXT,
            quantity INTEGER,
            cost_price REAL,
            date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name TEXT,
            quantity INTEGER,
            selling_price REAL,
            date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            amount REAL,
            date TEXT
          )
        ''');
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  static Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int> updateProduct(int id, Map<String, dynamic> row) async {
    final db = await database;
    return await db.update('products', row, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> sellProduct(Map<String, dynamic> prod, int qty) async {
    final db = await database;
    int currentQty = prod['quantity'] ?? 0;
    int newQty = currentQty - qty;
    if (newQty < 0) newQty = 0;

    await db.update('products', {'quantity': newQty}, where: 'id = ?', whereArgs: [prod['id']]);

    await db.insert('sales', {
      'product_id': prod['id'],
      'product_name': prod['name'],
      'quantity': qty,
      'buying_price': prod['buying_price'],
      'selling_price': prod['selling_price'],
      'date': DateTime.now().toString().split(' ')[0]
    });
  }

  static Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers');
  }

  static Future<int> insertCustomer(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('customers', row);
  }

  static Future<List<Map<String, dynamic>>> getCustomerItems(int customerId) async {
    final db = await database;
    return await db.query('customer_items', where: 'customer_id = ?', whereArgs: [customerId]);
  }

  static Future<void> addCreditToCustomer(int customerId, Map<String, dynamic> prod, int qty) async {
    final db = await database;
    double priceSum = (prod['selling_price'] as num).toDouble() * qty;

    int currentQty = prod['quantity'] ?? 0;
    int newQty = currentQty - qty >= 0 ? currentQty - qty : 0; // 👈 تأكد أنه مكتوب هكذا تماماً
    await db.update('products', {'quantity': newQty}, where: 'id = ?', whereArgs: [prod['id']]);

    await db.insert('customer_items', {
      'customer_id': customerId,
      'product_name': prod['name'],
      'quantity': qty,
      'price': priceSum,
      'date': DateTime.now().toString().split(' ')[0]
    });

    await db.execute('UPDATE customers SET debt = debt + ? WHERE id = ?', [priceSum, customerId]);
  }

  static Future<void> payDebt(int customerId, double amount) async {
    final db = await database;
    await db.execute('UPDATE customers SET debt = CASE WHEN (debt - ?) > 0 THEN (debt - ?) ELSE 0.0 END WHERE id = ?', [amount, amount, customerId]);
  }

  static Future<List<Map<String, dynamic>>> getCompanies() async {
    final db = await database;
    return await db.query('companies');
  }

  static Future<int> insertCompany(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('companies', row);
  }

  static Future<List<Map<String, dynamic>>> getCompanyInvoices(int companyId) async {
    final db = await database;
    return await db.query('company_invoices', where: 'company_id = ?', whereArgs: [companyId]);
  }

  static Future<void> addInvoiceToCompany(int companyId, String prodName, int qty, double cost) async {
    final db = await database;
    double totalCost = cost * qty;
    await db.insert('company_invoices', {
      'company_id': companyId,
      'product_name': prodName,
      'quantity': qty,
      'cost_price': totalCost,
      'date': DateTime.now().toString().split(' ')[0]
    });
    await db.execute('UPDATE companies SET total_debt = total_debt + ? WHERE id = ?', [totalCost, companyId]);
  }

  static Future<void> payCompanyDebt(int companyId, double amount) async {
    final db = await database;
    await db.execute('UPDATE companies SET total_debt = CASE WHEN (total_debt - ?) > 0 THEN (total_debt - ?) ELSE 0.0 END WHERE id = ?', [amount, amount, companyId]);
  }

  static Future<List<Map<String, dynamic>>> getReturns() async {
    final db = await database;
    return await db.query('returns');
  }

  static Future<int> insertReturn(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('returns', data);
  }

  static Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    return await db.query('sales');
  }

  static Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses');
  }

  static Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('expenses', row);
  }
}