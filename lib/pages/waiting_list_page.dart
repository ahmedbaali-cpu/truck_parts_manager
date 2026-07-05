import 'dart:async';
import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class WaitingListPage extends StatefulWidget {
  const WaitingListPage({super.key});

  @override
  State<WaitingListPage> createState() => _WaitingListPageState();
}

class _WaitingListPageState extends State<WaitingListPage> {
  final DbHelper _dbHelper = DbHelper();

  List<Map<String, dynamic>> _lowStockParts = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData(); // التحميل الأول مع دائرة التحميل

    // تشغيل مؤقت يحدّث البيانات كل 5 ثواني بصمت
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadDataSilently(); 
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel(); // إيقاف المؤقت عند الخروج من الصفحة لتوفير الذاكرة
    super.dispose();
  }

  // دالة موحدة لجلب البيانات من قاعدة البيانات (لتجنب التكرار)
  Future<List<Map<String, dynamic>>> _fetchDataFromDB() async {
    final db = await _dbHelper.database;
    
    // جلب القطع التي كميتها 3 أو أقل
    final lowStockData = await db.rawQuery('''
      SELECT * FROM products 
      WHERE CAST(quantity AS INTEGER) <= 3 
         OR quantity IS NULL 
         OR quantity = ''
      ORDER BY CAST(quantity AS INTEGER) ASC
    ''');
    
    List<Map<String, dynamic>> enrichedData = [];

    // البحث عن تاريخ آخر خروج (بيع) لكل قطعة
    for (var part in lowStockData) {
      String lastOutDate = '-';
      
      try {
        final salesRes = await db.rawQuery('SELECT date FROM sales WHERE product_id = ? ORDER BY date DESC LIMIT 1', [part['id']]);
        final creditRes = await db.rawQuery('SELECT date FROM customer_items WHERE product_name = ? ORDER BY date DESC LIMIT 1', [part['name']]);
        
        DateTime? latestDate;

        if (salesRes.isNotEmpty && salesRes.first['date'] != null) {
          latestDate = DateTime.tryParse(salesRes.first['date'].toString());
        }

        if (creditRes.isNotEmpty && creditRes.first['date'] != null) {
          final cDate = DateTime.tryParse(creditRes.first['date'].toString());
          if (cDate != null) {
            if (latestDate == null || cDate.isAfter(latestDate)) {
              latestDate = cDate;
            }
          }
        }

        if (latestDate != null) {
          lastOutDate = latestDate.toString().substring(0, 16);
        }
      } catch (e) {
        debugPrint("Error fetching last out date: $e");
      }

      enrichedData.add({
        ...part,
        'last_out_date': lastOutDate,
      });
    }
    return enrichedData;
  }

  // دالة التحميل الأول (تُظهر دائرة التحميل)
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final data = await _fetchDataFromDB();
    
    if (!mounted) return;
    setState(() {
      _lowStockParts = data;
      _isLoading = false;
    });
  }

  // دالة التحديث الصامت (لا تغير _isLoading لكي لا ترمش الشاشة)
  Future<void> _loadDataSilently() async {
    final data = await _fetchDataFromDB();
    
    if (!mounted) return;
    setState(() {
      _lowStockParts = data;
    });
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'تنبيهات نقص المخزون (${_lowStockParts.length})',
        'col_ref': 'المرجع (Ref)',
        'col_name_brand': 'اسم القطعة والبراند',
        'col_shelf': 'الرف / الموقع',
        'col_stock': 'الكمية الحالية',
        'col_last_out': 'آخر خروج / نفاذ',
        'empty_low': 'رائع! لا توجد أي قطع مخزون منخفضة حالياً، كل السلع متوفرة.',
      },
      'en': {
        'title': 'Low Stock Alerts (${_lowStockParts.length})',
        'col_ref': 'Reference',
        'col_name_brand': 'Part Name & Brand',
        'col_shelf': 'Shelf Location',
        'col_stock': 'Stock Qty',
        'col_last_out': 'Last Out / Sold',
        'empty_low': 'Excellent! No low stock items detected.',
      },
      'fr': {
        'title': 'Alertes de stock bas (${_lowStockParts.length})',
        'col_ref': 'Référence',
        'col_name_brand': 'Nom & Marque',
        'col_shelf': 'Rayon',
        'col_stock': 'Quantité',
        'col_last_out': 'Dernière Sortie',
        'empty_low': 'Excellent ! Aucun article en rupture de stock.',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key]!;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                Text(
                  _getTxt('title', currentLang), 
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0087B7)))
                  : _buildLowStockTable(currentLang, isDark),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockTable(String lang, bool isDark) {
    if (_lowStockParts.isEmpty) {
      return Center(
        child: Text(
          _getTxt('empty_low', lang), 
          style: const TextStyle(color: Colors.grey, fontSize: 16)
        )
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
            columns: [
              DataColumn(label: Text(_getTxt('col_ref', lang))),
              DataColumn(label: Text(_getTxt('col_name_brand', lang))),
              DataColumn(label: Text(_getTxt('col_shelf', lang))),
              DataColumn(label: Text(_getTxt('col_stock', lang))),
              DataColumn(label: Text(_getTxt('col_last_out', lang))), 
            ],
            rows: _lowStockParts.map((part) {
              int qty = int.tryParse(part['quantity']?.toString() ?? '0') ?? 0;
              return DataRow(cells: [
                DataCell(Text(part['reference'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${part['name']} (${part['brand'] ?? '-'})')),
                DataCell(Text(part['shelf'] ?? '-')),
                DataCell(Text(
                  '$qty',
                  style: TextStyle(
                    color: qty <= 0 ? Colors.red : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                  ),
                )),
                DataCell(Text(
                  part['last_out_date'] ?? '-',
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}