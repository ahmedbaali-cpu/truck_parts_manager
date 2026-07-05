import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DbHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'truck_parts_pro.db');
    
    return await openDatabase(
      dbPath,
      version: 9, // تم رفع الإصدار إلى 9 لدعم أرقام هواتف الزبائن
      onCreate: (db, version) async {
        // 1. Products / Stocks
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reference TEXT UNIQUE,
            name TEXT,
            brand TEXT,
            shelf TEXT,
            buying_price REAL,
            selling_price REAL,
            quantity INTEGER,
            image_path TEXT
          )
        ''');

        // 2. Direct Sales Records (تمت إضافة invoice_number)
        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_number TEXT,
            product_id INTEGER,
            product_name TEXT,
            quantity INTEGER,
            buying_price REAL,
            selling_price REAL,
            date TEXT
          )
        ''');

        // 3. Customers Ledger (تمت إضافة عمود phone هنا)
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            phone TEXT, 
            debt REAL DEFAULT 0.0
          )
        ''');

        // 4. Customer Credit Item Ledger
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

        // 5. Supplier Companies Ledger
        await db.execute('''
          CREATE TABLE companies (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_name TEXT,
            company_contact TEXT,
            company_debt REAL DEFAULT 0.0
          )
        ''');

        // 6. Supplier Batch Invoices Ledger
        await db.execute('''
          CREATE TABLE company_invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id INTEGER,
            reference TEXT,
            name TEXT,
            quantity_bought INTEGER,
            cost_charged REAL,
            date_added TEXT
          )
        ''');

        // 7. Returns Table
        await db.execute('''
          CREATE TABLE returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_name TEXT,
            quantity INTEGER,
            selling_price REAL,
            date TEXT
          )
        ''');

        // 8. Staff / General Expenses Table
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            amount REAL,
            type TEXT, -- 'staff' or 'general'
            date TEXT
          )
        ''');

        // 9. Waiting List Table
        await db.execute('''
          CREATE TABLE waiting_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_name TEXT,
            customer_phone TEXT,
            part_requested TEXT,
            date_requested TEXT
          )
        ''');

        // 10. Workers / Employees Table
        await db.execute('''
          CREATE TABLE workers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            role TEXT,
            phone TEXT,
            base_salary REAL
          )
        ''');

        // 11. Worker Salary & Financial Transactions Ledger
        await db.execute('''
          CREATE TABLE worker_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            worker_id INTEGER,
            type TEXT, -- 'Salary', 'Advance', 'Bonus', 'Deduction'
            amount REAL,
            notes TEXT,
            date TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE IF NOT EXISTS workers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, role TEXT, phone TEXT, base_salary REAL)');
          await db.execute('CREATE TABLE IF NOT EXISTS worker_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, worker_id INTEGER, type TEXT, amount REAL, notes TEXT, date TEXT)');
        }
        if (oldVersion < 5) {
          await db.execute('CREATE TABLE IF NOT EXISTS customers (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, debt REAL DEFAULT 0.0)');
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
          } catch (e) {
            print("Column image_path might already exist: $e");
          }
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE sales ADD COLUMN invoice_number TEXT');
          } catch (e) {
            print("Column invoice_number might already exist: $e");
          }
        }
        if (oldVersion < 9) {
          // تحديث قاعدة البيانات القديمة لتستقبل رقم الهاتف بدون حذف بيانات الزبائن
          try {
            await db.execute('ALTER TABLE customers ADD COLUMN phone TEXT');
          } catch (e) {
            print("Column phone might already exist: $e");
          }
        }
      },
    );
  }

  // ==========================================
  // PRODUCTS METHODS
  // ==========================================
  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.query('products');
  }

  Future<int> insertProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Map<String, dynamic> row) async {
    final db = await database;
    return await db.update('products', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> sellProduct(Map<String, dynamic> prod, int qty, String invoiceNumber) async {
    final db = await database;
    
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity - ? WHERE id = ?',
      [qty, prod['id']],
    );

    await db.insert('sales', {
      'invoice_number': invoiceNumber,
      'product_id': prod['id'],
      'product_name': prod['name'],
      'quantity': qty,
      'buying_price': prod['buying_price'],
      'selling_price': prod['selling_price'],
      'date': DateTime.now().toString().split(' ')[0]
    });
  }

  Future<int> insertSale(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('sales', row);
  }

  // ==========================================
  // BULLETPROOF CUSTOMERS METHODS
  // ==========================================
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query('customers', orderBy: 'id DESC');
  }

  Future<int> insertCustomer(dynamic input) async {
    final db = await database;
    
    try {
      if (input is Map) {
        final Map<String, dynamic> cleanRow = {};
        
        cleanRow['name'] = input['name'] ?? 
                           input['Name'] ?? 
                           input['customer_name'] ?? 
                           input['clientName'] ?? 
                           input['client_name'] ?? 
                           'Unknown Customer';
        
        // تم إضافة حفظ رقم الهاتف هنا
        cleanRow['phone'] = input['phone']?.toString() ?? '';
                           
        cleanRow['debt'] = double.tryParse(input['debt']?.toString() ?? '') ?? 0.0;
        
        return await db.insert('customers', cleanRow);
      } 
      else if (input is String) {
        return await db.insert('customers', {
          'name': input.trim().isEmpty ? 'Unknown Customer' : input.trim(),
          'phone': '',
          'debt': 0.0,
        });
      }
    } catch (e) {
      print("Error inserting customer: $e");
    }
    
    return -1;
  }

  Future<List<Map<String, dynamic>>> getCustomerItems(int customerId) async {
    final db = await database;
    return await db.query('customer_items', where: 'customer_id = ?', whereArgs: [customerId]);
  }

  Future<void> addCreditToCustomer(int customerId, Map<String, dynamic> prod, int qty) async {
    final db = await database;
    double priceSum = (prod['selling_price'] as num).toDouble() * qty;

    int currentQty = prod['quantity'] ?? 0;
    int newQty = (currentQty - qty) < 0 ? 0 : (currentQty - qty);
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

  Future<void> payDebt(int customerId, double amount) async {
    final db = await database;
    await db.execute('UPDATE customers SET debt = CASE WHEN (debt - ?) > 0 THEN (debt - ?) ELSE 0.0 END WHERE id = ?', [amount, amount, customerId]);
  }

  // ==========================================
  // SUPPLIER COMPANIES METHODS 
  // ==========================================
  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    final db = await database;
    return await db.query('companies');
  }

  Future<void> createNewCompany(String name, String contact) async {
    final db = await database;
    await db.insert('companies', {
      'company_name': name,
      'company_contact': contact,
      'company_debt': 0.0
    });
  }

  Future<List<Map<String, dynamic>>> getCompanyItems(int companyId) async {
    final db = await database;
    return await db.query('company_invoices', where: 'company_id = ?', whereArgs: [companyId]);
  }

  Future<void> addPartToCompanyFile({
    required int companyId,
    required String reference,
    required String name,
    required int qty,
    required double cost,
  }) async {
    final db = await database;
    double totalCost = cost * qty;

    await db.insert('company_invoices', {
      'company_id': companyId,
      'reference': reference,
      'name': name,
      'quantity_bought': qty,
      'cost_charged': cost,
      'date_added': DateTime.now().toString()
    });

    await db.execute('UPDATE companies SET company_debt = company_debt + ? WHERE id = ?', [totalCost, companyId]);

    await db.insert('products', {
      'reference': reference,
      'name': name,
      'buying_price': cost,
      'selling_price': cost * 1.25,
      'quantity': qty
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> recordCompanyPayment(int companyId, double amount) async {
    final db = await database;
    await db.execute(
      'UPDATE companies SET company_debt = CASE WHEN (company_debt - ?) > 0 THEN (company_debt - ?) ELSE 0.0 END WHERE id = ?',
      [amount, amount, companyId]
    );
  }

  // ==========================================
  // WAITING LIST & LOW STOCK METHODS 
  // ==========================================
  Future<List<Map<String, dynamic>>> getWaitingList() async {
    final db = await database;
    return await db.query('waiting_list', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getLowStockParts() async {
    final db = await database;
    return await db.query('products', where: 'quantity <= ?', whereArgs: [3]);
  }

  Future<void> insertWaitingRequest(String name, String phone, String item) async {
    final db = await database;
    await db.insert('waiting_list', {
      'customer_name': name,
      'customer_phone': phone,
      'part_requested': item,
      'date_requested': DateTime.now().toString()
    });
  }

  Future<void> deleteWaitingRequest(int id) async {
    final db = await database;
    await db.delete('waiting_list', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // RETURNS, SALES, EXPENSES LISTINGS
  // ==========================================
  
  // 🟢 الإضافة الجديدة: دالة إرجاع السلع (Returns)
  Future<void> processReturn({
    required int saleId, 
    required int productId, 
    required String productName,
    required int quantityToReturn,
    required double sellingPrice
  }) async {
    final db = await database;
    
    await db.transaction((txn) async {
      // 1. إرجاع الكمية إلى المخزن
      await txn.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [quantityToReturn, productId]
      );

      // 2. حذف العملية من سجل المبيعات
      await txn.delete(
        'sales', 
        where: 'id = ?', 
        whereArgs: [saleId]
      );

      // 3. تسجيل العملية في جدول المرتجعات (returns) لكي تبقى في السجل
      await txn.insert('returns', {
        'product_name': productName,
        'quantity': quantityToReturn,
        'selling_price': sellingPrice,
        'date': DateTime.now().toString().split(' ')[0]
      });
    });
  }

  Future<List<Map<String, dynamic>>> getReturns() async {
    final db = await database;
    return await db.query('returns', orderBy: 'id DESC');
  }

  Future<int> insertReturn(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('returns', data);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await database;
    // تم التعديل لعرض المبيعات من الأحدث إلى الأقدم لسهولة المراجعة والإرجاع
    return await db.query('sales', orderBy: 'id DESC'); 
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses');
  }

  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('expenses', row);
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // ENHANCED WORKERS / EMPLOYEES LOGIC METHODS
  // ==========================================
  Future<List<Map<String, dynamic>>> getAllWorkers() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT w.*, 
        (w.base_salary - 
         IFNULL((SELECT SUM(amount) FROM worker_transactions WHERE worker_id = w.id AND type = 'Deduction'), 0)
        ) AS salary_after_deduction,
        (w.base_salary + 
         IFNULL((SELECT SUM(amount) FROM worker_transactions WHERE worker_id = w.id AND type = 'Bonus'), 0) - 
         IFNULL((SELECT SUM(amount) FROM worker_transactions WHERE worker_id = w.id AND type = 'Deduction'), 0) - 
         IFNULL((SELECT SUM(amount) FROM worker_transactions WHERE worker_id = w.id AND type = 'Advance'), 0) -
         IFNULL((SELECT SUM(amount) FROM worker_transactions WHERE worker_id = w.id AND type = 'Salary'), 0)
        ) AS current_due_salary
      FROM workers w
      ORDER BY w.id DESC
    ''');
  }

  Future<int> insertWorker(String name, String role, String phone, double baseSalary) async {
    final db = await database;
    return await db.insert('workers', {
      'name': name,
      'role': role,
      'phone': phone,
      'base_salary': baseSalary,
    });
  }

  Future<int> updateWorkerProfile(int id, String name, String role, String phone, double baseSalary) async {
    final db = await database;
    return await db.update(
      'workers', 
      {
        'name': name,
        'role': role,
        'phone': phone,
        'base_salary': baseSalary,
      },
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<int> deleteWorker(int id) async {
    final db = await database;
    await db.delete('worker_transactions', where: 'worker_id = ?', whereArgs: [id]);
    return await db.delete('workers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getWorkerTransactions(int workerId) async {
    final db = await database;
    return await db.query('worker_transactions', where: 'worker_id = ?', whereArgs: [workerId], orderBy: 'id DESC');
  }

  Future<int> insertSalaryTransaction(int workerId, String type, double amount, String notes) async {
    final db = await database;
    String today = DateTime.now().toIso8601String();
    
    if (type == 'Salary' || type == 'Advance' || type == 'Bonus') {
      await db.insert('expenses', {
        'title': 'Staff Payout ($type) - Worker ID $workerId ($notes)',
        'amount': amount,
        'type': 'staff',
        'date': today,
      });
    }

    return await db.insert('worker_transactions', {
      'worker_id': workerId,
      'type': type,
      'amount': amount,
      'notes': notes,
      'date': today,
    });
  }

  // ==========================================
  // FINANCIAL REPORTS COMPILATION WITH CALENDAR FILTER
  // ==========================================
  Future<Map<String, dynamic>> getFinancialReport({String? selectedDate}) async {
    final db = await database;

    String salesDateFilter = selectedDate != null ? " WHERE date = '$selectedDate' " : "";
    String expenseDateFilter = selectedDate != null ? " AND date LIKE '$selectedDate%' " : "";

    final salesRes = await db.rawQuery('SELECT SUM(quantity * selling_price) as total FROM sales $salesDateFilter');
    double totalSales = (salesRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final debtRes = await db.rawQuery('SELECT SUM(debt) as total FROM customers');
    double customerDebts = (debtRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final staffRes = await db.rawQuery("SELECT SUM(amount) as total FROM expenses WHERE type = 'staff' $expenseDateFilter");
    double staffExpenses = (staffRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final generalRes = await db.rawQuery("SELECT SUM(amount) as total FROM expenses WHERE type != 'staff' $expenseDateFilter");
    double generalExpenses = (generalRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final stockRes = await db.rawQuery('SELECT SUM(quantity * buying_price) as cost, SUM(quantity * selling_price) as value FROM products');
    double inventoryCost = (stockRes.first['cost'] as num?)?.toDouble() ?? 0.0;
    double inventoryValue = (stockRes.first['value'] as num?)?.toDouble() ?? 0.0;

    final marginRes = await db.rawQuery('SELECT SUM(quantity * (selling_price - buying_price)) as margin_profit FROM sales $salesDateFilter');
    double profitMarginFromSales = (marginRes.first['margin_profit'] as num?)?.toDouble() ?? 0.0;
    double netProfit = profitMarginFromSales - (staffExpenses + generalExpenses);

    return {
      'total_sales': totalSales,
      'customer_debts': customerDebts,
      'staff_expenses': staffExpenses,
      'general_expenses': generalExpenses,
      'inventory_cost': inventoryCost,
      'inventory_value': inventoryValue,
      'net_profit': netProfit,
    };
  }
}