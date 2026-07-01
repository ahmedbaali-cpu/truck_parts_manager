import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _cart = [];
  double _total = 0.0;
  final _barcodeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() async {
    final data = await DBHelper.getProducts();
    setState(() { _products = data; });
  }

  void _addToCart(Map<String, dynamic> product) {
    if (product['quantity'] <= 0) return;
    setState(() {
      _cart.add(product);
      _total += product['selling_price'];
    });
  }

  void _handleBarcodeScan(String code) {
    if (code.isEmpty) return;
    try {
      final product = _products.firstWhere(
        (p) => p['reference'].toString().toLowerCase() == code.toLowerCase().trim()
      );
      _addToCart(product);
      _barcodeCtrl.clear();
    } catch (_) {
      // Product not found
    }
  }

  void _checkout() async {
    if (_cart.isEmpty) return;
    for (var item in _cart) {
      await DBHelper.sellProduct(item, 1);
    }
    setState(() {
      _cart.clear();
      _total = 0.0;
    });
    _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت عملية البيع بنجاح وتحديث الكميات بالمخزن الرئيسي.'))
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('شاشة البيع السريع ونقاط البيع POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                children: [
                  TextField(
                    controller: _barcodeCtrl,
                    onSubmitted: _handleBarcodeScan,
                    decoration: InputDecoration(
                      hintText: 'قم بتوجيه قارئ الباركود هنا أو اكتب الكود المرجعي يدوياً للبيع الفوري...',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      fillColor: theme.cardColor,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.3
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, idx) {
                        final p = _products[idx];
                        bool hasStock = p['quantity'] > 0;
                        return InkWell(
                          onTap: hasStock ? () => _addToCart(p) : null,
                          child: Card(
                            color: theme.cardColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: hasStock ? const Color(0xFFE2E8F0) : Colors.red.withOpacity(0.3))
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${p['selling_price']} DA', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                                      Text('المخزون: ${p['quantity']}', style: TextStyle(color: hasStock ? Colors.grey : Colors.red, fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: const Border(right: BorderSide(color: Color(0xFFE2E8F0)))
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('سلة المبيعات الحالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('السلة فارغة، قم باختيار قطع الغيار لبدء البيع.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (c, idx) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_cart[idx]['name'], style: const TextStyle(fontSize: 13)),
                              trailing: Text('${_cart[idx]['selling_price']} DA', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع الإجمالي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('$_total DA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                    child: const Text('تأكيد الدفع وطباعة الوصل', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}