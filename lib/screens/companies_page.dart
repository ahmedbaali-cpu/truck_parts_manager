import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

// Fixed: Changed class name from CreditPage to CompaniesPage
class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<Map<String, dynamic>> _companies = [];
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final data = await DBHelper.getCustomers(); 
      setState(() { _companies = data; });
    } catch (e) {
      setState(() { _companies = []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشركات والموردين')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _nameCtrl.clear();
                _phoneCtrl.clear();
              },
              child: const Text('إضافة شركة جديدة'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _companies.length,
                itemBuilder: (context, idx) => ListTile(
                  title: Text(_companies[idx]['name'] ?? 'شركة غير معروفة'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}