import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  final _refCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _buyCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_filterSearch);
  }

  void _loadData() async {
    final data = await DBHelper.getProducts();
    setState(() {
      _allProducts = data;
      _filteredProducts = data;
    });
  }

  void _filterSearch() {
    String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        return p['name'].toString().toLowerCase().contains(query) ||
               p['reference'].toString().toLowerCase().contains(query);
      }).toList();
    });
  }

  void _showAddDialog() {
    _refCtrl.clear(); _nameCtrl.clear(); _buyCtrl.clear(); _sellCtrl.clear(); _qtyCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة قطعة غيار جديدة للمخزن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'المرجع / Barcode')),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم القطعة')),
            TextField(controller: _buyCtrl, decoration: const InputDecoration(labelText: 'سعر الشراء (DA)'), keyboardType: TextInputType.number),
            TextField(controller: _sellCtrl, decoration: const InputDecoration(labelText: 'سعر البيع (DA)'), keyboardType: TextInputType.number),
            TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية الابتدائية'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.isEmpty || _sellCtrl.text.isEmpty) return;
              await DBHelper.insertProduct({
                'reference': _refCtrl.text,
                'name': _nameCtrl.text,
                'buying_price': double.tryParse(_buyCtrl.text) ?? 0.0,
                'selling_price': double.tryParse(_sellCtrl.text) ?? 0.0,
                'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
              });
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('حفظ القطعة'),
          )
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> p) {
    _refCtrl.text = p['reference'] ?? '';
    _nameCtrl.text = p['name'] ?? '';
    _buyCtrl.text = p['buying_price'].toString();
    _sellCtrl.text = p['selling_price'].toString();
    _qtyCtrl.text = p['quantity'].toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات قطعة الغيار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'المرجع / Barcode')),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم القطعة')),
            TextField(controller: _buyCtrl, decoration: const InputDecoration(labelText: 'سعر الشراء (DA)'), keyboardType: TextInputType.number),
            TextField(controller: _sellCtrl, decoration: const InputDecoration(labelText: 'سعر البيع (DA)'), keyboardType: TextInputType.number),
            TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              await DBHelper.updateProduct(p['id'], {
                'reference': _refCtrl.text,
                'name': _nameCtrl.text,
                'buying_price': double.tryParse(_buyCtrl.text) ?? 0.0,
                'selling_price': double.tryParse(_sellCtrl.text) ?? 0.0,
                'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
              });
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('تحديث'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('المخزن المركزي وجرد السلع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة سلع جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن طريق اسم قطعة الغيار أو الكود المرجعي الرقمي...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      fillColor: theme.cardColor,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                color: theme.cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(theme.brightness == Brightness.light ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)),
                          columns: const [
                            DataColumn(label: Text('الكود المرجعي')),
                            DataColumn(label: Text('اسم قطعة الغيار')),
                            DataColumn(label: Text('سعر الشراء')),
                            DataColumn(label: Text('سعر البيع')),
                            DataColumn(label: Text('المخزون الحالي')),
                            DataColumn(label: Text('إجراءات التحكم')),
                          ],
                          rows: _filteredProducts.map((p) {
                            bool isLowStock = (p['quantity'] ?? 0) <= 3;
                            return DataRow(
                              cells: [
                                DataCell(Text(p['reference'] ?? '-')),
                                DataCell(Text(p['name'] ?? '-')),
                                DataCell(Text('${p['buying_price']} DA')),
                                DataCell(Text('${p['selling_price']} DA')),
                                DataCell(Text(
                                  '${p['quantity']}',
                                  style: TextStyle(
                                    color: isLowStock ? Colors.red : Colors.green[700], 
                                    fontWeight: FontWeight.bold
                                  ),
                                )),
                                DataCell(Row(
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => _showEditDialog(p)),
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async {
                                      await DBHelper.deleteProduct(p['id']);
                                      _loadData();
                                    }),
                                  ],
                                )),
                              ]
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}