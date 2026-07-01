import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  List<Map<String, dynamic>> _returnsLog = [];
  final _prodNameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: "1");
  final _priceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final logs = await DBHelper.getReturns();
    setState(() { _returnsLog = logs; });
  }

  void _processReturn() async {
    if (_prodNameCtrl.text.isEmpty || _priceCtrl.text.isEmpty) return;
    await DBHelper.insertReturn({
      'product_name': _prodNameCtrl.text,
      'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
      'selling_price': double.tryParse(_priceCtrl.text) ?? 0.0,
      'date': DateTime.now().toString().split(' ')[0],
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل السلعة المسترجعة وإعادتها للنظام')));
    _prodNameCtrl.clear(); _priceCtrl.clear();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('إدارة مرتجعات السلع والقطع المردودة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: _prodNameCtrl, decoration: const InputDecoration(labelText: 'اسم السلعة المرتجعة'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'إجمالي السعر المسترد (DA)'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(onPressed: _processReturn, icon: const Icon(Icons.assignment_return), label: const Text('تسجيل إرجاع'))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(theme.brightness == Brightness.light ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)),
                        columns: const [\
                          DataColumn(label: Text('تاريخ وتوقيت الإرجاع')),\
                          DataColumn(label: Text('اسم قطعة الغيار المستلمة')),\
                          DataColumn(label: Text('الكمية')),\
                          DataColumn(label: Text('إجمالي المبالغ النقدية المرتجعة'))\
                        ],\
                        rows: _returnsLog.map((log) => DataRow(cells: [\
                          DataCell(Text(log['date'] ?? '')),\
                          DataCell(Text(log['product_name'] ?? '')),\
                          DataCell(Text('${log['quantity']}')),\
                          DataCell(Text('${log['selling_price']} DA', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),\
                        ])).toList(),\
                      ),\
                    ],\
                  ),\
                ),\
              ),\
            )\
          ],\
        ),\
      ),\
    );\
  }\
}\