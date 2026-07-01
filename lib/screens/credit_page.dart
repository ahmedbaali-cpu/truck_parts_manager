import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class CreditPage extends StatefulWidget {
  const CreditPage({super.key});

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _selectedCustomerItems = [];

  int? _selectedCustomerId;
  int? _selectedProductId;

  final _customerNameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: "1");
  final _payCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final custs = await DBHelper.getCustomers();
    final prods = await DBHelper.getProducts();
    setState(() {
      _customers = custs;
      _products = prods;
      _selectedProductId = null;
    });
    if (_selectedCustomerId != null) {
      _loadCustomerProfile(_selectedCustomerId!);
    }
  }

  void _loadCustomerProfile(int id) async {
    final items = await DBHelper.getCustomerItems(id);
    setState(() { _selectedCustomerItems = items; });
  }

  void _createNewCustomer() async {
    if (_customerNameCtrl.text.isEmpty) return;
    await DBHelper.insertCustomer({'name': _customerNameCtrl.text, 'debt': 0.0});
    _customerNameCtrl.clear();
    _loadData();
  }

  void _addCreditItem() async {
    if (_selectedCustomerId == null || _selectedProductId == null) return;
    final prod = _products.firstWhere((p) => p['id'] == _selectedProductId);
    int qty = int.tryParse(_qtyCtrl.text) ?? 1;

    await DBHelper.addCreditToCustomer(_selectedCustomerId!, prod, qty);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('إدارة ديون وكريدي الزبائن والعملاء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customerNameCtrl,
                          decoration: const InputDecoration(hintText: 'اسم الزبون الجديد بالكامل...'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _createNewCustomer,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('فتح حساب للزبون'),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      child: ListView.builder(
                        itemCount: _customers.length,
                        itemBuilder: (context, index) {
                          final c = _customers[index];
                          bool isSelected = _selectedCustomerId == c['id'];
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: theme.colorScheme.secondary.withOpacity(0.1),
                            title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text('${c['debt']} DA', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            onTap: () {
                              setState(() { _selectedCustomerId = c['id']; });
                              _loadCustomerProfile(c['id']);
                            },
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _selectedCustomerId == null
                ? const Center(child: Text('الرجاء اختيار زبون من القائمة لعرض كشف الحساب والديون.'))
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تسجيل سلعة جديدة في حساب الكريدي', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          hint: const Text('اختر قطعة الغيار المستلمة'),
                          value: _selectedProductId,
                          items: _products.map((p) => DropdownMenuItem<int>(value: p['id'], child: Text(p['name']))).toList(),
                          onChanged: (val) => setState(() { _selectedProductId = val; }),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية المستلمة'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            ElevatedButton(onPressed: _addCreditItem, child: const Text('إضافة للكريدي')),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _payCtrl, decoration: const InputDecoration(labelText: 'المبلغ المدفوع نقداً (DA)'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (_payCtrl.text.isEmpty) return;
                                await DBHelper.payDebt(_selectedCustomerId!, double.tryParse(_payCtrl.text) ?? 0.0);
                                _payCtrl.clear();
                                _loadData();
                              },
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('تسجيل الدفعة المالية النقدية'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Card(
                            child: ListView.builder(
                              itemCount: _selectedCustomerItems.length,
                              itemBuilder: (context, idx) {
                                final item = _selectedCustomerItems[idx];
                                return ListTile(
                                  title: Text(item['product_name'] ?? ''),
                                  subtitle: Text('الكمية: ${item['quantity']} | التاريخ: ${item['date'] ?? ''}'),
                                  trailing: Text('${item['price'] ?? 0.0} DA', style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }
}