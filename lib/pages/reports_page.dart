import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DbHelper _dbHelper = DbHelper();
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  DateTime? _selectedDate; // Null indicates "All Time / Cumulative" stats

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // If a date is selected, extract the date part formatted as YYYY-MM-DD
    String? dateStr = _selectedDate != null 
        ? _selectedDate!.toIso8601String().split('T')[0] 
        : null;

    final data = await _dbHelper.getFinancialReport(selectedDate: dateStr);
    if (!mounted) return;
    
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0087B7),
              onPrimary: Colors.white,
              surface: Color(0xFF1A2A3A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  // مصفوفة الترجمات المحدثة بالكامل للغات الثلاث: العربية، الإنجليزية، والفرنسية
  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'التقارير المالية والمؤشرات الإحصائية',
        'refresh': 'تحديث البيانات',
        'sec_finance': 'الخلاصة المالية العامة',
        'sec_inv': 'تقييم رأس المال والمخزون الحالي',
        'lbl_sales': 'إجمالي المبيعات الكلية المكتسبة',
        'lbl_debts': 'مستحقات الديون الخارجية للزبائن',
        'lbl_staff': 'إجمالي رواتب ومصاريف العمال',
        'lbl_general': 'المصاريف التشغيلية العامة (شحن، فواتير...)',
        'lbl_inv_cost': 'تكلفة شراء المخزون الحالي (جملة)',
        'lbl_inv_val': 'القيمة السوقية المفترضة للمخزون (بيع)',
        'lbl_net_profit': 'صافي الأرباح الحقيقية الصافية',
        'net_profit_desc': 'الأرباح المحققة بعد طرح رواتب الموظفين والمصاريف العامة',
        'all_time': 'كل الأوقات',
        'clear_filter': 'إلغاء التصفية',
      },
      'en': {
        'title': 'Financial Reports & Analytics',
        'refresh': 'Refresh Data',
        'sec_finance': 'General Financial Summary',
        'sec_inv': 'Inventory Valuation & Capital',
        'lbl_sales': 'Total Sales Earned',
        'lbl_debts': 'Total Customer Debts Outstanding',
        'lbl_staff': 'Total Staff Salaries & Wages Paid',
        'lbl_general': 'General Expenses (Rent, Bills...)',
        'lbl_inv_cost': 'Current Inventory Cost (Wholesale)',
        'lbl_inv_val': 'Current Inventory Value (Retail)',
        'lbl_net_profit': 'Net Realized Profit',
        'net_profit_desc': 'Earned profit after deducting staff salaries and general expenses',
        'all_time': 'All Time',
        'clear_filter': 'Clear Filter',
      },
      'fr': {
        'title': 'Rapports Financiers & Statistiques',
        'refresh': 'Actualiser les Données',
        'sec_finance': 'Résumé Financier Général',
        'sec_inv': 'Valorisation des Stocks & Capital',
        'lbl_sales': 'Total des Ventes Réalisées',
        'lbl_debts': 'Total des Dettes Clients Exceptionnelles',
        'lbl_staff': 'Total des Salaires et Dépenses du Personnel',
        'lbl_general': 'Frais Généraux (Loyer, Factures...)',
        'lbl_inv_cost': 'Coût Actuel du Stock (Achat)',
        'lbl_inv_val': 'Valeur Actuelle du Stock (Vente)',
        'lbl_net_profit': 'Bénéfice Net Réalisé',
        'net_profit_desc': 'Bénéfice gagné après déduction des salaires et des frais généraux',
        'all_time': 'Tout le temps',
        'clear_filter': 'Effacer le filtre',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const String currency = 'DA';

    // استخراج القيم المالية مع حماية البيانات من قيم null
    double totalSales = (_reportData['total_sales'] as num?)?.toDouble() ?? 0.0;
    double customerDebts = (_reportData['customer_debts'] as num?)?.toDouble() ?? 0.0;
    double staffExpenses = (_reportData['staff_expenses'] as num?)?.toDouble() ?? 0.0;
    double generalExpenses = (_reportData['general_expenses'] as num?)?.toDouble() ?? 0.0;
    double inventoryCost = (_reportData['inventory_cost'] as num?)?.toDouble() ?? 0.0;
    double inventoryValue = (_reportData['inventory_value'] as num?)?.toDouble() ?? 0.0;
    double netProfit = (_reportData['net_profit'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0087B7)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // العنوان الرئيسي وزر التحديث وفلتر التقويم المدمج
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _getTxt('title', currentLang),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            if (_selectedDate != null) ...[
                              TextButton.icon(
                                icon: const Icon(Icons.clear, color: Colors.redAccent, size: 16),
                                label: Text(_getTxt('clear_filter', currentLang), style: const TextStyle(color: Colors.redAccent)),
                                onPressed: () {
                                  setState(() => _selectedDate = null);
                                  _loadReport();
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => _pickDate(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0087B7)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0087B7), size: 18),
                              label: Text(
                                _selectedDate == null 
                                    ? _getTxt('all_time', currentLang) 
                                    : _selectedDate!.toIso8601String().split('T')[0],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0087B7)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _loadReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0087B7),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(_getTxt('refresh', currentLang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // القسم الأول: الخلاصة المالية العامة
                    Text(
                      _getTxt('sec_finance', currentLang),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0087B7)),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      childAspectRatio: 3.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildReportCard(_getTxt('lbl_sales', currentLang), '${totalSales.toStringAsFixed(2)} $currency', Icons.trending_up, Colors.green, isDark),
                        _buildReportCard(_getTxt('lbl_debts', currentLang), '${customerDebts.toStringAsFixed(2)} $currency', Icons.money_off, Colors.redAccent, isDark),
                        _buildReportCard(_getTxt('lbl_staff', currentLang), '${staffExpenses.toStringAsFixed(2)} $currency', Icons.badge_outlined, Colors.purple, isDark),
                        _buildReportCard(_getTxt('lbl_general', currentLang), '${generalExpenses.toStringAsFixed(2)} $currency', Icons.receipt_long_outlined, Colors.orange, isDark),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // القسم الثاني: تقييم رأس المال والمخزون الحالي
                    Text(
                      _getTxt('sec_inv', currentLang),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0087B7)),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      childAspectRatio: 3.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildReportCard(_getTxt('lbl_inv_cost', currentLang), '${inventoryCost.toStringAsFixed(2)} $currency', Icons.inventory_2_outlined, Colors.teal, isDark),
                        _buildReportCard(_getTxt('lbl_inv_val', currentLang), '${inventoryValue.toStringAsFixed(2)} $currency', Icons.shopify_outlined, Colors.blue, isDark),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // بطاقة صافي الأرباح الكبرى الملونة في الأسفل
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: netProfit >= 0 
                              ? [const Color(0xFF10B981), const Color(0xFF059669)] 
                              : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))
                        ]
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_balance, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getTxt('lbl_net_profit', currentLang),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getTxt('net_profit_desc', currentLang),
                                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${netProfit.toStringAsFixed(2)} $currency',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 24,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title, 
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.grey[600], fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value, 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}