import 'dart:async';
import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _filteredExpenses = [];
  List<Map<String, dynamic>> _workers = [];
  
  bool _isLoading = true;
  double _totalExpensesAmount = 0.0;
  String _selectedFilterCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final db = await _dbHelper.database;
    final data = await db.query('expenses', orderBy: 'id DESC');
    
    if (!mounted) return;
    setState(() {
      _allExpenses = data;
    });
    
    await _applyFilter(_selectedFilterCategory);
  }

  Future<void> _applyFilter(String category) async {
    setState(() {
      _selectedFilterCategory = category;
      if (category == 'All') {
        _filteredExpenses = _allExpenses;
      } else {
        _filteredExpenses = _allExpenses.where((e) => e['type'] == category).toList();
      }
      _totalExpensesAmount = _filteredExpenses.fold(0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0.0));
    });

    if (category == 'staff') {
      await _loadWorkers();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    final db = await _dbHelper.database;
    final data = await db.query('workers');
    
    String currentMonth = DateTime.now().toString().substring(0, 7); // yyyy-MM
    List<Map<String, dynamic>> enrichedWorkers = [];
    
    for(var w in data) {
      final res = await db.rawQuery(
        "SELECT SUM(amount) as total FROM worker_transactions WHERE worker_id = ? AND date LIKE ?",
        [w['id'], '$currentMonth%']
      );
      double paid = (res.first['total'] as num?)?.toDouble() ?? 0.0;
      double base = (w['base_salary'] as num?)?.toDouble() ?? 0.0;
      
      enrichedWorkers.add({
        ...w,
        'paid_this_month': paid,
        'remaining_salary': base - paid,
      });
    }
    
    if (!mounted) return;
    setState(() {
      _workers = enrichedWorkers;
      _isLoading = false;
    });
  }

  Future<void> _deleteExpense(int id) async {
    final db = await _dbHelper.database;
    await db.rawDelete('DELETE FROM expenses WHERE id = ?', [id]);
    _loadExpenses();
  }

  void _showAddExpenseDialog(BuildContext context, String lang) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String category = 'Utilities';
    final formKey = GlobalKey<FormState>();

    // فئة الرواتب (staff) لا تظهر هنا، لأن الرواتب تُدفع من جدول الموظفين للحفاظ على الدقة
    final List<Map<String, String>> categories = [
      {'id': 'Rent', 'ar': 'إيجار العقار', 'en': 'Rent', 'fr': 'Loyer'},
      {'id': 'Utilities', 'ar': 'فواتير (كهرباء/ماء/إنترنت)', 'en': 'Utilities', 'fr': 'Factures (Électricité/Eau)'},
      {'id': 'Shipping', 'ar': 'شحن ونقل', 'en': 'Shipping & Transport', 'fr': 'Livraison & Transport'},
      {'id': 'Government', 'ar': 'رسوم حكومية وضرائب', 'en': 'Taxes & Gov', 'fr': 'Taxes & Impôts'},
      {'id': 'Other', 'ar': 'مصاريف نثرية أخرى', 'en': 'Other Expenses', 'fr': 'Autres Frais'},
    ];

    String dialogTitle = 'Record New Expense';
    String labelCategory = 'Category';
    String labelTitle = 'Expense Title / Purpose';
    String labelAmount = 'Amount';
    String labelNotes = 'Additional Notes (Optional)';
    String btnCancel = 'Cancel';
    String btnSave = 'Save Expense';

    if (lang == 'ar') {
      dialogTitle = 'تسجيل مصروف جديد';
      labelCategory = 'فئة المصروف';
      labelTitle = 'بيان المصروف (العنوان)';
      labelAmount = 'المبلغ المستحق';
      labelNotes = 'ملاحظات إضافية';
      btnCancel = 'إلغاء';
      btnSave = 'حفظ المصروف';
    } else if (lang == 'fr') {
      dialogTitle = 'Enregistrer une nouvelle dépense';
      labelCategory = 'Catégorie';
      labelTitle = 'Description / Motif';
      labelAmount = 'Montant';
      labelNotes = 'Notes supplémentaires (Optionnel)';
      btnCancel = 'Annuler';
      btnSave = 'Enregistrer';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(labelText: labelCategory),
                      items: categories.map((cat) {
                        String categoryLabel = cat['en']!;
                        if (lang == 'ar') categoryLabel = cat['ar']!;
                        if (lang == 'fr') categoryLabel = cat['fr']!;
                        return DropdownMenuItem(
                          value: cat['id'],
                          child: Text(categoryLabel),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: labelTitle),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: labelAmount),
                      validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid Number' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(labelText: labelNotes),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel, style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final db = await _dbHelper.database;
                      String now = DateTime.now().toString().split(' ')[0];
                      String notes = notesController.text.trim();
                      String fullTitle = notes.isNotEmpty ? '${titleController.text.trim()} - $notes' : titleController.text.trim();

                      await db.insert('expenses', {
                        'title': fullTitle,
                        'amount': double.parse(amountController.text.trim()),
                        'type': category,
                        'date': now
                      });
                      
                      if (context.mounted) Navigator.pop(context);
                      _loadExpenses();
                    }
                  },
                  child: Text(btnSave),
                )
              ],
            );
          }
        );
      }
    );
  }

  void _showPayWorkerDialog(Map<String, dynamic> worker, String lang) {
    final amountController = TextEditingController();
    final notesController = TextEditingController(text: lang == 'ar' ? 'سلفة / راتب شهري' : 'Salary / Advance');
    final formKey = GlobalKey<FormState>();

    double maxPay = (worker['remaining_salary'] as num).toDouble();
    if (maxPay < 0) maxPay = 0;

    String title = 'Pay / Deduct from Wage';
    String hint = 'Amount (DA)';
    String notesHint = 'Notes (e.g., Advance, Full Salary)';
    String valReq = 'Required';
    String valInvalid = 'Invalid amount';
    String btnCancel = 'Cancel';
    String btnPay = 'Confirm Payment';

    if (lang == 'ar') {
      title = 'صرف راتب / خصم سلفة من الموظف';
      hint = 'المبلغ المراد صرفه وخصمه (DA)';
      notesHint = 'ملاحظات (مثال: سلفة، راتب شهر...)';
      valReq = 'مطلوب';
      valInvalid = 'مبلغ غير صالح';
      btnCancel = 'إلغاء';
      btnPay = 'تأكيد الخصم والصرف';
    } else if (lang == 'fr') {
      title = 'Payer le salaire / Avance';
      hint = 'Montant (DA)';
      notesHint = 'Notes (ex: Avance, Salaire)';
      valReq = 'Obligatoire';
      valInvalid = 'Montant invalide';
      btnCancel = 'Annuler';
      btnPay = 'Confirmer le paiement';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${worker['name']} - ${worker['role']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${lang == 'ar' ? 'الراتب المتبقي لهذا الشهر:' : 'Remaining this month:'} ${maxPay.toStringAsFixed(2)} DA', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: hint, suffixText: 'DA'),
                validator: (v) {
                  if (v == null || v.isEmpty) return valReq;
                  final amt = double.tryParse(v);
                  if (amt == null || amt <= 0) return valInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                decoration: InputDecoration(labelText: notesHint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double payAmt = double.parse(amountController.text.trim());
                String notes = notesController.text.trim();
                
                final db = await _dbHelper.database;
                String now = DateTime.now().toString().split(' ')[0];
                
                // 1. تسجيل العملية في حساب الموظف
                await db.insert('worker_transactions', {
                  'worker_id': worker['id'],
                  'type': 'Salary', 
                  'amount': payAmt,
                  'notes': notes,
                  'date': now
                });
                
                // 2. تسجيلها كمصروف عام أوتوماتيكياً
                await db.insert('expenses', {
                  'title': 'Payroll: ${worker['name']} - $notes',
                  'amount': payAmt,
                  'type': 'staff',
                  'date': now
                });

                if (context.mounted) Navigator.pop(context);
                _loadExpenses(); 
              }
            },
            child: Text(btnPay),
          )
        ],
      ),
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'سجل المصاريف والنفقات',
        'sub': 'إجمالي المصاريف للفئة المحددة:',
        'btn_new': 'إضافة مصروف',
        'col_title': 'البيان / الوصف',
        'col_cat': 'الفئة',
        'col_amt': 'المبلغ',
        'col_date': 'التاريخ',
        'col_actions': 'إجراءات',
        'empty': 'لا توجد مصاريف مسجلة في هذه الفئة.',
        'All': 'الكل',
        'Rent': 'إيجار (Rent)',
        'Utilities': 'فواتير (Utilities)',
        'Shipping': 'شحن ونقل (Shipping)',
        'Government': 'ضرائب ورسوم (Gov)',
        'Other': 'أخرى (Other)',
        'staff': 'رواتب الموظفين (Payroll)',
        // worker columns
        'w_name': 'اسم الموظف',
        'w_role': 'المنصب',
        'w_base': 'الراتب الشهري',
        'w_paid': 'مستلم (هذا الشهر)',
        'w_rem': 'المتبقي لصالحه',
        'w_action': 'دفع / خصم',
        'w_empty': 'لم يتم العثور على موظفين. يرجى إضافتهم من إدارة الموظفين.',
      },
      'en': {
        'title': 'Expenses & Outflows Ledger',
        'sub': 'Total Expenses for Selected Category:',
        'btn_new': 'New Expense',
        'col_title': 'Description',
        'col_cat': 'Category',
        'col_amt': 'Amount',
        'col_date': 'Date',
        'col_actions': 'Actions',
        'empty': 'No expenses recorded in this category.',
        'All': 'All',
        'Rent': 'Rent',
        'Utilities': 'Utilities',
        'Shipping': 'Shipping',
        'Government': 'Gov & Taxes',
        'Other': 'Other',
        'staff': 'Staff Payroll',
        // worker columns
        'w_name': 'Employee Name',
        'w_role': 'Role',
        'w_base': 'Base Salary',
        'w_paid': 'Paid (This Month)',
        'w_rem': 'Remaining',
        'w_action': 'Pay / Deduct',
        'w_empty': 'No staff found. Please add them in Staff Management.',
      },
      'fr': {
        'title': 'Registre des Dépenses',
        'sub': 'Total des dépenses pour cette catégorie :',
        'btn_new': 'Nouvelle Dépense',
        'col_title': 'Description',
        'col_cat': 'Catégorie',
        'col_amt': 'Montant',
        'col_date': 'Date',
        'col_actions': 'Actions',
        'empty': 'Aucune dépense enregistrée dans cette catégorie.',
        'All': 'Tout',
        'Rent': 'Loyer',
        'Utilities': 'Factures',
        'Shipping': 'Livraison',
        'Government': 'Impôts & Taxes',
        'Other': 'Autres',
        'staff': 'Salaires Personnel',
        // worker columns
        'w_name': 'Nom de l\'employé',
        'w_role': 'Poste',
        'w_base': 'Salaire de base',
        'w_paid': 'Payé (Ce mois)',
        'w_rem': 'Reste à payer',
        'w_action': 'Payer / Déduire',
        'w_empty': 'Aucun employé trouvé. Veuillez les ajouter dans la gestion du personnel.',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key] ?? key;
  }

  Widget _buildWorkersTable(String lang, bool isDark, String currency) {
    if (_workers.isEmpty) {
      return Center(child: Text(_getTxt('w_empty', lang), style: const TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
        columns: [
          DataColumn(label: Text(_getTxt('w_name', lang))),
          DataColumn(label: Text(_getTxt('w_role', lang))),
          DataColumn(label: Text(_getTxt('w_base', lang))),
          DataColumn(label: Text(_getTxt('w_paid', lang))),
          DataColumn(label: Text(_getTxt('w_rem', lang))),
          DataColumn(label: Text(_getTxt('w_action', lang))),
        ],
        rows: _workers.map((worker) {
          double base = (worker['base_salary'] as num?)?.toDouble() ?? 0.0;
          double paid = (worker['paid_this_month'] as num?)?.toDouble() ?? 0.0;
          double rem = (worker['remaining_salary'] as num?)?.toDouble() ?? 0.0;

          return DataRow(cells: [
            DataCell(Text(worker['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(worker['role'] ?? '-')),
            DataCell(Text('${base.toStringAsFixed(2)} $currency')),
            DataCell(Text('${paid.toStringAsFixed(2)} $currency', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            DataCell(Text('${rem.toStringAsFixed(2)} $currency', style: TextStyle(color: rem > 0 ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.bold))),
            DataCell(
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                icon: const Icon(Icons.payments, size: 16),
                label: Text(_getTxt('w_action', lang)),
                onPressed: () => _showPayWorkerDialog(worker, lang),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildExpensesTable(String lang, bool isDark, String currency) {
    if (_filteredExpenses.isEmpty) {
      return Center(child: Text(_getTxt('empty', lang), style: const TextStyle(color: Colors.grey)));
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
        columns: [
          DataColumn(label: Text(_getTxt('col_title', lang))),
          DataColumn(label: Text(_getTxt('col_cat', lang))),
          DataColumn(label: Text(_getTxt('col_amt', lang))),
          DataColumn(label: Text(_getTxt('col_date', lang))),
          DataColumn(label: Text(_getTxt('col_actions', lang))),
        ],
        rows: _filteredExpenses.map((exp) {
          String rawDate = exp['date'] ?? '';
          String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
          String expCategory = exp['type'] ?? 'Other';
          double amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;

          return DataRow(cells: [
            DataCell(Text(exp['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(_getTxt(expCategory, lang))),
            DataCell(Text('${amt.toStringAsFixed(2)} $currency', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            DataCell(Text(formattedDate)),
            DataCell(
              expCategory == 'staff' 
              ? const SizedBox.shrink() // إخفاء زر الحذف لرواتب الموظفين للحفاظ على تطابق السجلات
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _deleteExpense(exp['id']),
                ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const String currency = 'DA';
    
    final List<String> filterCategories = ['All', 'Rent', 'Utilities', 'Shipping', 'Government', 'Other', 'staff'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${_getTxt('sub', currentLang)} ${_totalExpensesAmount.toStringAsFixed(2)} $currency',
                        style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddExpenseDialog(context, currentLang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0087B7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(_getTxt('btn_new', currentLang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterCategories.map((cat) {
                  bool isSelected = _selectedFilterCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_getTxt(cat, currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0087B7),
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                      labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                      onSelected: (selected) {
                        if (selected) {
                           _applyFilter(cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0087B7)))
                    : _selectedFilterCategory == 'staff'
                        ? _buildWorkersTable(currentLang, isDark, currency)
                        : _buildExpensesTable(currentLang, isDark, currency),
              ),
            ),
          ],
        ),
      ),
    );
  }
}