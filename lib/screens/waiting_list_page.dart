import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class WaitingListPage extends StatefulWidget {
  const WaitingListPage({super.key});

  @override
  State<WaitingListPage> createState() => _WaitingListPageState();
}

class _WaitingListPageState extends State<WaitingListPage> {
  List<Map<String, dynamic>> _outOfStockItems = [];
  List<Map<String, dynamic>> _lowStockItems = [];

  @override
  void initState() {
    super.initState();
    _loadWaitingList();
  }

  void _loadWaitingList() async {
    final data = await DBHelper.getProducts();
    List<Map<String, dynamic>> outOfStock = [];
    List<Map<String, dynamic>> lowStock = [];

    for (var p in data) {
      int qty = p['quantity'] ?? 0;
      if (qty == 0) {
        outOfStock.add(p);
      } else if (qty <= 3) {
        lowStock.add(p);
      }
    }
    setState(() {
      _outOfStockItems = outOfStock;
      _lowStockItems = lowStock;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('قائمة النواقص والسلع المطلوبة للمخزن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: const [Icon(Icons.cancel, color: Colors.red, size: 20), SizedBox(width: 8), Text('قطع غيار نفدت تماماً (الكمية = 0)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red))]),
                      const Divider(height: 24),
                      Expanded(
                        child: _outOfStockItems.isEmpty
                            ? const Center(child: Text('ممتاز! لا توجد قطع منتهية تماماً في المخزن.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _outOfStockItems.length,
                                itemBuilder: (context, index) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_outOfStockItems[index]['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  trailing: const Text('طلب فوري 🚨', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: const [Icon(Icons.error, color: Colors.orange, size: 20), SizedBox(width: 8), Text('قطع منخفضة المخزون (أقل من 3)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange))]),
                      const Divider(height: 24),
                      Expanded(
                        child: _lowStockItems.isEmpty
                            ? const Center(child: Text('كل كميات القطع الحالية في الحدود الآمنة.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _lowStockItems.length,
                                itemBuilder: (context, index) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_lowStockItems[index]['name'], style: const TextStyle(fontSize: 13)),
                                  trailing: Text('الكمية المتبقية: ${_lowStockItems[index]['quantity']} ⚠️', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}