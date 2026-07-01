import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedDate = DateTime.now();
  double _totalSalesRevenue = 0.0;
  double _totalExpenses = 0.0;
  double _netProfit = 0.0;

  List<Map<String, dynamic>> _filteredSalesList = [];
  List<Map<String, dynamic>> _filteredExpensesList = [];

  final _expenseTitleCtrl = TextEditingController();
  final _expenseAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _calculateFinancesForDate(_selectedDate);
  }

  void _calculateFinancesForDate(DateTime targetDate) async {
    String targetDateStr = targetDate.toString().split(' ')[0];
    final allSales = await DBHelper.getSales();
    final allExpenses = await DBHelper.getExpenses();
    final allReturns = await DBHelper.getReturns();

    double salesRevenue = 0.0;
    double grossProfit = 0.0;
    double expensesSum = 0.0;
    double returnsSum = 0.0;

    List<Map<String, dynamic>> todaySales = [];
    List<Map<String, dynamic>> todayExpenses = [];

    for (var s in allSales) {
      if (s['date'] == targetDateStr) {
        todaySales.add(s);
        double sellPrice = (s['selling_price'] as num).toDouble();
        double buyPrice = (s['buying_price'] as num).toDouble();
        int qty = s['quantity'] ?? 1;

        salesRevenue += (sellPrice * qty);
        grossProfit += ((sellPrice - buyPrice) * qty);
      }
    }

    for (var e in allExpenses) {
      if (e['date'] == targetDateStr) {
        todayExpenses.add(e);
        expensesSum += (e['amount'] as num).toDouble();
      }
    }

    for (var r in allReturns) {
      if (r['date'] == targetDateStr) {
        returnsSum += (r['selling_price'] as num).toDouble();
      }
    }

    setState(() {
      _totalSalesRevenue = salesRevenue;
      _totalExpenses = expensesSum;
      _filteredSalesList = todaySales;
      _filteredExpensesList = todayExpenses;
      _netProfit = grossProfit - expensesSum - returnsSum;
    });
  }

  void _addNewExpense() async {
    if (_expenseTitleCtrl.text.isEmpty || _expenseAmountCtrl.text.isEmpty) return;
    await DBHelper.insertExpense({
      'title': _expenseTitleCtrl.text,
      'amount': double.tryParse(_expenseAmountCtrl.text) ?? 0.0,
      'date': _selectedDate.toString().split(' ')[0]
    });
    _expenseTitleCtrl.clear(); _expenseAmountCtrl.clear();
    _calculateFinancesForDate(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('التقارير المالية والأرباح اليومية الخالصة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('تاريخ التقرير المالي المعروض: ${_selectedDate.toString().split(' ')[0]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) {
                      setState(() { _selectedDate = picked; });
                      _calculateFinancesForDate(picked);
                    }
                  },
                  icon: const Icon(Icons.date_range, size: 16),
                  label: const Text('تغيير تاريخ اليوم'),
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildKPICard('إجمالي مدخول المبيعات', '$_totalSalesRevenue DA', Colors.blue[800]!)),
                const SizedBox(width: 16),
                Expanded(child: _buildKPICard('إجمالي المصاريف الفرعية', '$_totalExpenses DA', Colors.red[700]!)),
                const SizedBox(width: 16),
                Expanded(child: _buildKPICard('صافي الأرباح اليومية', '$_netProfit DA', Colors.teal[700]!)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('تسجيل مصاريف إضافية خارج السلع (كهرباء، كراء...)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(controller: _expenseTitleCtrl, decoration: const InputDecoration(labelText: 'بيان المصروف')),
                            TextField(controller: _expenseAmountCtrl, decoration: const InputDecoration(labelText: 'المبلغ (DA)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _addNewExpense, child: const Text('تسجيل الخروج المالي')),
                            const Divider(height: 24),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _filteredExpensesList.length,
                                itemBuilder: (c, idx) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_filteredExpensesList[idx]['title']),
                                  trailing: Text('- ${_filteredExpensesList[idx]['amount']} DA', style: const TextStyle(color: Colors.red)),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('كشف المبيعات المفصل لليوم', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Divider(height: 24),
                            Expanded(
                              child: _filteredSalesList.isEmpty
                                  ? const Center(child: Text('لا توجد مبيعات مسجلة في هذا التاريخ.', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: _filteredSalesList.length,
                                      itemBuilder: (c, idx) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(_filteredSalesList[idx]['product_name'], style: const TextStyle(fontSize: 13)),
                                        trailing: Text('+ ${_filteredSalesList[idx]['selling_price']} DA', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                            )
                          ],
                        ),
                      ),
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

  Widget _buildKPICard(String subtitle, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}