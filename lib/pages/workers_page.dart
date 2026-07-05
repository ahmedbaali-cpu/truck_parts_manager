import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class WorkersPage extends StatefulWidget {
  const WorkersPage({super.key});

  @override
  State<WorkersPage> createState() => _WorkersPageState();
}

class _WorkersPageState extends State<WorkersPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _workers = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedWorker;
  List<Map<String, dynamic>> _selectedWorkerTx = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final data = await _dbHelper.getAllWorkers();
    if (!mounted) return;

    Map<String, dynamic>? targetWorker;
    
    if (data.isNotEmpty) {
      if (_selectedWorker != null) {
        // Retain selection safely using ID mapping
        targetWorker = data.firstWhere(
          (w) => w['id'] == _selectedWorker!['id'],
          orElse: () => data.first,
        );
      } else {
        targetWorker = data.first;
      }
    }

    // Load the transactions outside of the main list setState block
    List<Map<String, dynamic>> targetTx = [];
    if (targetWorker != null) {
      targetTx = await _dbHelper.getWorkerTransactions(targetWorker['id']);
    }

    if (!mounted) return;
    setState(() {
      _workers = data;
      _selectedWorker = targetWorker;
      _selectedWorkerTx = targetTx;
      _isLoading = false;
    });
  }

  Future<void> _selectWorker(Map<String, dynamic> worker) async {
    final tx = await _dbHelper.getWorkerTransactions(worker['id']);
    if (!mounted) return;
    setState(() {
      _selectedWorker = worker;
      _selectedWorkerTx = tx;
    });
  }

  // نافذة تعديل بيانات موظف / راتب أساسي
  void _showEditWorkerDialog(BuildContext context, String lang, Map<String, dynamic> worker) {
    final nameController = TextEditingController(text: worker['name']);
    final roleController = TextEditingController(text: worker['role']);
    final phoneController = TextEditingController(text: worker['phone'] ?? '');
    final salaryController = TextEditingController(text: worker['base_salary']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    String dialogTitle = 'Edit Employee Profile';
    String labelName = 'Full Name';
    String labelRole = 'Role / Position';
    String labelPhone = 'Phone Number';
    String labelSalary = 'Base Monthly Salary';
    String valRequired = 'Required';
    String valInvalid = 'Invalid Amount';
    String btnCancel = 'Cancel';
    String btnSave = 'Save Changes';

    if (lang == 'ar') {
      dialogTitle = 'تعديل بيانات الموظف والراتب';
      labelName = 'اسم الموظف الثلاثي';
      labelRole = 'الوظيفة (بائع، محاسب...)';
      labelPhone = 'رقم الهاتف';
      labelSalary = 'الراتب الأساسي الثابت';
      valRequired = 'مطلوب';
      valInvalid = 'رقم غير صالح';
      btnCancel = 'إلغاء';
      btnSave = 'حفظ التعديلات';
    } else if (lang == 'fr') {
      dialogTitle = 'Modifier le Profil de l\'Employé';
      labelName = 'Nom Complet';
      labelRole = 'Rôle / Poste';
      labelPhone = 'Numéro de Téléphone';
      labelSalary = 'Salaire Mensuel de Base';
      valRequired = 'Obligatoire';
      valInvalid = 'Montant Invalide';
      btnCancel = 'Annuler';
      btnSave = 'Enregistrer';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(dialogTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: labelName),
                validator: (v) => v!.isEmpty ? valRequired : null,
              ),
              TextFormField(
                controller: roleController,
                decoration: InputDecoration(labelText: labelRole),
                validator: (v) => v!.isEmpty ? valRequired : null,
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: labelPhone),
              ),
              TextFormField(
                controller: salaryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: labelSalary),
                validator: (v) => double.tryParse(v ?? '') == null ? valInvalid : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _dbHelper.updateWorkerProfile(
                  worker['id'],
                  nameController.text.trim(),
                  roleController.text.trim(),
                  phoneController.text.trim(),
                  double.parse(salaryController.text.trim()),
                );
                if (context.mounted) Navigator.pop(context);
                _loadWorkers();
              }
            },
            child: Text(btnSave),
          )
        ],
      ),
    );
  }

  // تأكيد وحذف ملف موظف بالكامل
  void _showDeleteConfirmation(BuildContext context, String lang, Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(lang == 'ar' ? 'حذف الموظف؟' : (lang == 'fr' ? 'Supprimer l\'employé?' : 'Delete Employee?')),
        content: Text(
          lang == 'ar' 
              ? 'هل أنت متأكد من حذف الموظف "${worker['name']}" بشكل نهائي؟ سيتم حذف جميع سجلاته المالية وحركاته أيضاً.' 
              : (lang == 'fr' 
                  ? 'Êtes-vous sûr de vouloir supprimer définitivement "${worker['name']}"? Toutes ses transactions seront supprimées.' 
                  : 'Are you sure you want to permanently delete "${worker['name']}"? This will also remove all their transaction ledgers.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(lang == 'ar' ? 'إلغاء' : (lang == 'fr' ? 'Annuler' : 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await _dbHelper.deleteWorker(worker['id']);
              if (context.mounted) Navigator.pop(context);
              setState(() {
                _selectedWorker = null;
              });
              _loadWorkers();
            },
            child: Text(lang == 'ar' ? 'تأكيد الحذف' : (lang == 'fr' ? 'Supprimer' : 'Delete')),
          )
        ],
      ),
    );
  }

  // نافذة إضافة موظف جديد تدعم اللغات الثلاثة بالكامل
  void _showAddWorkerDialog(BuildContext context, String lang) {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String dialogTitle = 'Add New Employee';
    String labelName = 'Full Name';
    String labelRole = 'Role / Position';
    String labelPhone = 'Phone Number';
    String labelSalary = 'Base Monthly Salary';
    String valRequired = 'Required';
    String valInvalid = 'Invalid Amount';
    String btnCancel = 'Cancel';
    String btnSave = 'Save';

    if (lang == 'ar') {
      dialogTitle = 'إضافة موظف جديد';
      labelName = 'اسم الموظف الثلاثي';
      labelRole = 'الوظيفة (بائع، محاسب...)';
      labelPhone = 'رقم الهاتف';
      labelSalary = 'الراتب الأساسي الثابت';
      valRequired = 'مطلوب';
      valInvalid = 'رقم غير صالح';
      btnCancel = 'إلغاء';
      btnSave = 'حفظ';
    } else if (lang == 'fr') {
      dialogTitle = 'Ajouter un Nouvel Employé';
      labelName = 'Nom Complet';
      labelRole = 'Rôle / Poste';
      labelPhone = 'Numéro de Téléphone';
      labelSalary = 'Salaire Mensuel de Base';
      valRequired = 'Obligatoire';
      valInvalid = 'Montant Invalide';
      btnCancel = 'Annuler';
      btnSave = 'Enregistrer';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(dialogTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: labelName),
                validator: (v) => v!.isEmpty ? valRequired : null,
              ),
              TextFormField(
                controller: roleController,
                decoration: InputDecoration(labelText: labelRole),
                validator: (v) => v!.isEmpty ? valRequired : null,
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: labelPhone),
              ),
              TextFormField(
                controller: salaryController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: labelSalary),
                validator: (v) => double.tryParse(v ?? '') == null ? valInvalid : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0087B7),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _dbHelper.insertWorker(
                  nameController.text.trim(),
                  roleController.text.trim(),
                  phoneController.text.trim(),
                  double.parse(salaryController.text.trim()),
                );
                if (context.mounted) Navigator.pop(context);
                _loadWorkers();
              }
            },
            child: Text(btnSave),
          )
        ],
      ),
    );
  }

  // نافذة لتسجيل حركة مالية للموظف (راتب، سلفة، مكافأة، خصم)
  void _showTransactionDialog(BuildContext context, String lang, String type) {
    if (_selectedWorker == null) return;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String title = '';
    String labelAmount = lang == 'ar' ? 'المبلغ' : (lang == 'fr' ? 'Montant' : 'Amount');
    String labelNotes = lang == 'ar' ? 'ملاحظات / البيان' : (lang == 'fr' ? 'Notes / Description' : 'Notes / Description');
    String valInvalid = lang == 'ar' ? 'رقم غير صالح' : (lang == 'fr' ? 'Montant Invalide' : 'Invalid Amount');
    String btnCancel = lang == 'ar' ? 'إلغاء' : (lang == 'fr' ? 'Annuler' : 'Cancel');
    String btnConfirm = lang == 'ar' ? 'تأكيد العملية' : (lang == 'fr' ? 'Confirmer' : 'Confirm');

    if (type == 'Salary') {
      title = lang == 'ar' ? 'صرف راتب شهري' : (lang == 'fr' ? 'Payer le Salaire Mensuel' : 'Pay Monthly Salary');
    } else if (type == 'Advance') {
      title = lang == 'ar' ? 'تسجيل سلفة مالية' : (lang == 'fr' ? 'Enregistrer un Acompte' : 'Record Salary Advance');
    } else if (type == 'Bonus') {
      title = lang == 'ar' ? 'إضافة مكافأة' : (lang == 'fr' ? 'Ajouter une Prime' : 'Add Bonus');
    } else if (type == 'Deduction') {
      title = lang == 'ar' ? 'خصم من الراتب' : (lang == 'fr' ? 'Déduction de Salaire' : 'Deduction');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: labelAmount),
                validator: (v) => double.tryParse(v ?? '') == null ? valInvalid : null,
              ),
              TextFormField(
                controller: notesController,
                decoration: InputDecoration(labelText: labelNotes),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0087B7),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _dbHelper.insertSalaryTransaction(
                  _selectedWorker!['id'],
                  type,
                  double.parse(amountController.text.trim()),
                  notesController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
                _loadWorkers();
              }
            },
            child: Text(btnConfirm),
          )
        ],
      ),
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'إدارة طاقم العمل والرواتب',
        'add_worker': 'إضافة موظف',
        'list_title': 'قائمة الموظفين',
        'ledger_title': 'السجل المالي لـ',
        'base_sal': 'الراتب الثابت:',
        'deducted_sal': 'الراتب بعد الخصم:',
        'due_sal': 'المستحق الصافي:',
        'btn_pay': 'صرف راتب',
        'btn_adv': 'إعطاء سلفة',
        'btn_bonus': 'مكافأة',
        'btn_deduct': 'خصم',
        'btn_edit': 'تعديل الأجور والبيانات',
        'empty': 'لا يوجد موظفين مسجلين حالياً.',
        'col_type': 'نوع الحركة',
        'col_amount': 'المبلغ',
        'col_date': 'التاريخ',
        'col_notes': 'البيان/الملاحظات',
        'Salary': 'راتب شهري',
        'Advance': 'سلفة مالية',
        'Bonus': 'مكافأة',
        'Deduction': 'خصم',
      },
      'en': {
        'title': 'Staff & Payroll Management',
        'add_worker': 'Add Employee',
        'list_title': 'Staff Roster',
        'ledger_title': 'Financial Statement for',
        'base_sal': 'Base Salary:',
        'deducted_sal': 'Salary after Deduction:',
        'due_sal': 'Net Balance Due:',
        'btn_pay': 'Pay Salary',
        'btn_adv': 'Give Advance',
        'btn_bonus': 'Bonus',
        'btn_deduct': 'Deduct',
        'btn_edit': 'Edit Profile & Wages',
        'empty': 'No registered employees found.',
        'col_type': 'Transaction Type',
        'col_amount': 'Amount',
        'col_date': 'Date',
        'col_notes': 'Notes/Description',
        'Salary': 'Monthly Salary',
        'Advance': 'Advance',
        'Bonus': 'Bonus',
        'Deduction': 'Deduction',
      },
      'fr': {
        'title': 'Gestion du Personnel & Paie',
        'add_worker': 'Ajouter un Employé',
        'list_title': 'Liste du Personnel',
        'ledger_title': 'Relevé Financier de',
        'base_sal': 'Salaire de Base:',
        'deducted_sal': 'Salaire après Déduction:',
        'due_sal': 'Solde Net Dû:',
        'btn_pay': 'Payer Salaire',
        'btn_adv': 'Accorder Acompte',
        'btn_bonus': 'Prime',
        'btn_deduct': 'Déduction',
        'btn_edit': 'Modifier Profil / Salaire',
        'empty': 'Aucun employé enregistré pour le moment.',
        'col_type': 'Type de Transaction',
        'col_amount': 'Montant',
        'col_date': 'Date',
        'col_notes': 'Notes / Description',
        'Salary': 'Salaire Mensuel',
        'Advance': 'Acompte',
        'Bonus': 'Prime / Bonus',
        'Deduction': 'Déduction',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const String currency = 'DA';

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
                Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () => _showAddWorkerDialog(context, currentLang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0087B7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: Text(_getTxt('add_worker', currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0087B7)))
                  : _workers.isEmpty
                      ? Center(child: Text(_getTxt('empty', currentLang), style: const TextStyle(color: Colors.grey)))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // القائمة الجانبية للموظفين
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                child: ListView.separated(
                                  itemCount: _workers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final worker = _workers[index];
                                    final isSelected = _selectedWorker?['id'] == worker['id'];
                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: const Color(0xFF0087B7).withOpacity(0.08),
                                      onTap: () => _selectWorker(worker),
                                      leading: CircleAvatar(
                                        backgroundColor: isSelected ? const Color(0xFF0087B7) : (isDark ? Colors.white10 : Colors.grey[200]),
                                        foregroundColor: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black.withOpacity(0.7)),
                                        child: const Icon(Icons.person_outline, size: 18),
                                      ),
                                      title: Text(worker['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${worker['role']} | ${worker['phone'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                                      trailing: Text('${worker['base_salary']} $currency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0087B7))),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),

                            // سجل العمليات المالية للموظف المحدد
                            Expanded(
                              flex: 5,
                              child: _selectedWorker == null
                                  ? const SizedBox.shrink()
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${_getTxt('ledger_title', currentLang)} ${_selectedWorker!['name']}',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      OutlinedButton.icon(
                                                        onPressed: () => _showEditWorkerDialog(context, currentLang, _selectedWorker!),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: Colors.amber[800],
                                                          side: BorderSide(color: Colors.amber[700]!),
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        ),
                                                        icon: const Icon(Icons.edit_note_outlined, size: 16),
                                                        label: Text(_getTxt('btn_edit', currentLang), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                                                        tooltip: currentLang == 'ar' ? 'حذف الحساب' : 'Delete Employee',
                                                        onPressed: () => _showDeleteConfirmation(context, currentLang, _selectedWorker!),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              
                                              // Display calculation layouts explicitly
                                              Wrap(
                                                spacing: 16,
                                                runSpacing: 8,
                                                children: [
                                                  Text(
                                                    '${_getTxt('base_sal', currentLang)} ${_selectedWorker!['base_salary']} $currency',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
                                                  ),
                                                  Text(
                                                    '${_getTxt('deducted_sal', currentLang)} ${_selectedWorker!['salary_after_deduction'] ?? _selectedWorker!['base_salary']} $currency',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                                  ),
                                                  Text(
                                                    '${_getTxt('due_sal', currentLang)} ${_selectedWorker!['current_due_salary'] ?? _selectedWorker!['base_salary']} $currency',
                                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
                                                      onPressed: () => _showTransactionDialog(context, currentLang, 'Salary'),
                                                      child: Text(_getTxt('btn_pay', currentLang), style: const TextStyle(fontSize: 12)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0),
                                                      onPressed: () => _showTransactionDialog(context, currentLang, 'Advance'),
                                                      child: Text(_getTxt('btn_adv', currentLang), style: const TextStyle(fontSize: 12)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white, elevation: 0),
                                                      onPressed: () => _showTransactionDialog(context, currentLang, 'Bonus'),
                                                      child: Text(_getTxt('btn_bonus', currentLang), style: const TextStyle(fontSize: 12)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0),
                                                      onPressed: () => _showTransactionDialog(context, currentLang, 'Deduction'),
                                                      child: Text(_getTxt('btn_deduct', currentLang), style: const TextStyle(fontSize: 12)),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                            ),
                                            child: Scrollbar(
                                              thumbVisibility: true,
                                              trackVisibility: true,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.vertical,
                                                child: LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    return SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          minWidth: constraints.maxWidth,
                                                        ),
                                                        child: DataTable(
                                                          headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
                                                          columns: [
                                                            DataColumn(label: Text(_getTxt('col_type', currentLang))),
                                                            DataColumn(label: Text(_getTxt('col_amount', currentLang))),
                                                            DataColumn(label: Text(_getTxt('col_date', currentLang))),
                                                            DataColumn(label: Text(_getTxt('col_notes', currentLang))),
                                                          ],
                                                          rows: _selectedWorkerTx.map((tx) {
                                                            String txType = tx['type'] ?? '';
                                                            String rawDate = tx['date']?.toString() ?? '';
                                                            String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
                                                            return DataRow(cells: [
                                                              DataCell(
                                                                ConstrainedBox(
                                                                  constraints: const BoxConstraints(maxWidth: 120),
                                                                  child: Text(
                                                                    _getTxt(txType, currentLang), 
                                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                                    overflow: TextOverflow.ellipsis,
                                                                    maxLines: 1,
                                                                  ),
                                                                ),
                                                              ),
                                                              DataCell(Text('${tx['amount']} $currency', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                              DataCell(Text(formattedDate)),
                                                              DataCell(
                                                                ConstrainedBox(
                                                                  constraints: const BoxConstraints(maxWidth: 200),
                                                                  child: Text(
                                                                    tx['notes'] ?? '-',
                                                                    overflow: TextOverflow.ellipsis,
                                                                    maxLines: 1,
                                                                  ),
                                                                ),
                                                              ),
                                                            ]);
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}