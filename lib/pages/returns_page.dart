import 'dart:async';
import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key});

  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allSales = [];
  List<Map<String, dynamic>> _filteredSales = [];
  List<Map<String, dynamic>> _returnHistory = [];
  
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // تشغيل التحديث التلقائي الصامت كل 5 ثوانٍ
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadDataSilently();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final sales = await _dbHelper.getSales(); 
    final returns = await _dbHelper.getReturns();
    
    if (!mounted) return;
    setState(() {
      _allSales = sales.reversed.toList();
      _returnHistory = returns.reversed.toList();
      _filteredSales = _allSales;
      _isLoading = false;
    });
  }

  Future<void> _loadDataSilently() async {
    final sales = await _dbHelper.getSales(); 
    final returns = await _dbHelper.getReturns();
    
    if (!mounted) return;
    setState(() {
      _allSales = sales.reversed.toList();
      _returnHistory = returns.reversed.toList();
      
      if (_searchController.text.isNotEmpty) {
        _searchSales(_searchController.text);
      } else {
        _filteredSales = _allSales;
      }
    });
  }

  void _searchSales(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredSales = _allSales;
      } else {
        _filteredSales = _allSales.where((sale) {
          final inv = (sale['invoice_number'] ?? '').toString().toLowerCase();
          final name = (sale['product_name'] ?? '').toString().toLowerCase();
          return inv.contains(q) || name.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _processReturn(Map<String, dynamic> sale, int returnQty, String lang) async {
    final db = await _dbHelper.database; 

    try {
      await db.rawUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        [returnQty, sale['product_id']]
      );

      int remainingQty = (sale['quantity'] as int) - returnQty;
      if (remainingQty > 0) {
        await db.rawUpdate(
          'UPDATE sales SET quantity = ? WHERE id = ?',
          [remainingQty, sale['id']]
        );
      } else {
        await db.rawDelete('DELETE FROM sales WHERE id = ?', [sale['id']]);
      }

      await _dbHelper.insertReturn({
        'product_name': sale['product_name'],
        'quantity': returnQty,
        'selling_price': sale['selling_price'],
        'date': DateTime.now().toString().split(' ')[0] 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'ar' ? 'تم إرجاع السلعة للمخزن بنجاح!' : 'Item returned successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      _loadDataSilently(); 

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showReturnDialog(Map<String, dynamic> sale, String lang) {
    int maxQty = sale['quantity'] ?? 0;
    int selectedQty = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                lang == 'ar' ? 'إرجاع سلعة' : 'Return Item',
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${lang == 'ar' ? 'السلعة:' : 'Item:'} ${sale['product_name']}', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('${lang == 'ar' ? 'رقم الفاتورة:' : 'Invoice N°:'} ${sale['invoice_number']}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('${lang == 'ar' ? 'الكمية المباعة:' : 'Sold Qty:'} $maxQty', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Divider(height: 30),
                  Text(lang == 'ar' ? 'حدد الكمية المراد إرجاعها:' : 'Select quantity to return:'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 30),
                        onPressed: selectedQty > 1 ? () => setStateDialog(() => selectedQty--) : null,
                      ),
                      const SizedBox(width: 15),
                      Text('$selectedQty', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 30),
                        onPressed: selectedQty < maxQty ? () => setStateDialog(() => selectedQty++) : null,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang == 'ar' ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    foregroundColor: Colors.white
                  ),
                  onPressed: () {
                    Navigator.pop(context); 
                    _processReturn(sale, selectedQty, lang); 
                  },
                  child: Text(lang == 'ar' ? 'تأكيد الإرجاع' : 'Confirm Return'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'إدارة المرتجعات (Returns)',
        'search': 'ابحث برقم الفاتورة (BON N°) أو اسم القطعة...',
        'sales_history': 'سجل المبيعات (الفواتير)',
        'return_history': 'سجل المرتجعات السابقة',
        'btn_return': 'إرجاع',
        'col_invoice': 'رقم الفاتورة',
        'col_item': 'السلعة',
        'col_qty': 'الكمية',
        'col_price': 'السعر الإجمالي',
        'col_date': 'التاريخ',
        'col_action': 'إجراء',
        'empty_sales': 'لا توجد مبيعات.',
        'empty_returns': 'لا توجد مرتجعات مسجلة.',
      },
      'en': {
        'title': 'Returns Management',
        'search': 'Search by Invoice (BON N°) or Item Name...',
        'sales_history': 'Sales History',
        'return_history': 'Returns History',
        'btn_return': 'Return',
        'col_invoice': 'Invoice N°',
        'col_item': 'Item',
        'col_qty': 'Qty',
        'col_price': 'Total Price',
        'col_date': 'Date',
        'col_action': 'Action',
        'empty_sales': 'No sales found.',
        'empty_returns': 'No returns recorded.',
      },
      'fr': {
        'title': 'Gestion des Retours',
        'search': 'Rechercher par N° Facture (BON) ou Pièce...',
        'sales_history': 'Historique des Ventes',
        'return_history': 'Historique des Retours',
        'btn_return': 'Rembourser',
        'col_invoice': 'N° Facture',
        'col_item': 'Désignation',
        'col_qty': 'Qté',
        'col_price': 'Prix Total',
        'col_date': 'Date',
        'col_action': 'Action',
        'empty_sales': 'Aucune vente.',
        'empty_returns': 'Aucun retour enregistré.',
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ==========================================
                      // القسم الأيسر: سجل المبيعات والبحث
                      // ==========================================
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_getTxt('sales_history', currentLang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _searchController,
                              onChanged: _searchSales,
                              decoration: InputDecoration(
                                hintText: _getTxt('search', currentLang),
                                prefixIcon: const Icon(Icons.receipt_long),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1A2A3A) : Colors.grey[50],
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
                                child: Column(
                                  children: [
                                    // 🟢 ترويسة الجدول (تأخذ كامل العرض)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey[100],
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 2, child: Text(_getTxt('col_invoice', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 3, child: Text(_getTxt('col_item', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 1, child: Text(_getTxt('col_qty', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 2, child: Text(_getTxt('col_price', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 2, child: Text(_getTxt('col_action', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, thickness: 1),
                                    // 🟢 بيانات الجدول
                                    Expanded(
                                      child: _filteredSales.isEmpty 
                                        ? Center(child: Text(_getTxt('empty_sales', currentLang), style: const TextStyle(color: Colors.grey)))
                                        : ListView.separated(
                                            itemCount: _filteredSales.length,
                                            separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                            itemBuilder: (context, index) {
                                              final sale = _filteredSales[index];
                                              final double totalPrice = (sale['selling_price'] as num).toDouble() * (sale['quantity'] as int);
                                              
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  children: [
                                                    Expanded(flex: 2, child: Text(sale['invoice_number'] ?? '-', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
                                                    Expanded(flex: 3, child: Text(sale['product_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600))),
                                                    Expanded(flex: 1, child: Text('${sale['quantity']}')),
                                                    Expanded(flex: 2, child: Text('$totalPrice $currency', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                                                    Expanded(
                                                      flex: 2, 
                                                      child: Align(
                                                        alignment: currentLang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                                                        child: ElevatedButton.icon(
                                                          onPressed: () => _showReturnDialog(sale, currentLang),
                                                          icon: const Icon(Icons.keyboard_return, size: 16),
                                                          label: Text(_getTxt('btn_return', currentLang)),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.redAccent,
                                                            foregroundColor: Colors.white,
                                                            elevation: 0,
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            minimumSize: const Size(0, 36)
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 24),

                      // ==========================================
                      // القسم الأيمن: سجل المرتجعات السابقة
                      // ==========================================
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_getTxt('return_history', currentLang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                child: Column(
                                  children: [
                                    // 🟢 ترويسة جدول المرتجعات
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.grey[100],
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(flex: 3, child: Text(_getTxt('col_item', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 1, child: Text(_getTxt('col_qty', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          Expanded(flex: 2, child: Text(_getTxt('col_date', currentLang), style: const TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, thickness: 1),
                                    // 🟢 بيانات المرتجعات
                                    Expanded(
                                      child: _returnHistory.isEmpty 
                                        ? Center(child: Text(_getTxt('empty_returns', currentLang), style: const TextStyle(color: Colors.grey)))
                                        : ListView.separated(
                                            itemCount: _returnHistory.length,
                                            separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                            itemBuilder: (context, index) {
                                              final ret = _returnHistory[index];
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3, 
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.assignment_return, color: Colors.redAccent, size: 16),
                                                          const SizedBox(width: 8),
                                                          Expanded(child: Text(ret['product_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                        ],
                                                      )
                                                    ),
                                                    Expanded(
                                                      flex: 1, 
                                                      child: Text('${ret['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))
                                                    ),
                                                    Expanded(
                                                      flex: 2, 
                                                      child: Text(ret['date'] ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 13))
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
    );
  }
}