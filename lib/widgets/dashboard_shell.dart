import 'package:flutter/material.dart';

// Correct absolute package paths based on your folder structure
import 'package:truck_parts_manager/pages/inventory_page.dart';
import 'package:truck_parts_manager/pages/sales_page.dart';
import 'package:truck_parts_manager/pages/reports_page.dart';
import 'package:truck_parts_manager/pages/returns_page.dart';
import 'package:truck_parts_manager/pages/credit_page.dart';
import 'package:truck_parts_manager/pages/companies_page.dart';
import 'package:truck_parts_manager/pages/waiting_list_page.dart';
import 'package:truck_parts_manager/pages/settings_page.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  // All 8 of your uploaded functional pages mapped in order
  final List<Widget> _views = [
    const InventoryPage(),   // 0. المخزن
    const SalesPage(),       // 1. المبيعات
    const ReturnsPage(),     // 2. المرتجعات
    const CreditPage(),      // 3. الديون
    const Companies_Page(),   // 4. الشركات (Note: Check if your class name in companies_page.dart matches this, or adjust to match)
    const WaitingListPage(), // 5. قائمة الانتظار
    const ReportsPage(),     // 6. التقارير
    const SettingsPage(),    // 7. الإعدادات
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Menu Layout
          NavigationDrawer(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
                child: Text(
                  'إدارة قطع الشاحنات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('المخزن / القطع'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: Text('المبيعات والفواتير'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.assignment_return_outlined),
                selectedIcon: Icon(Icons.assignment_return),
                label: Text('السلع المرتجعة'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.monetization_on_outlined),
                selectedIcon: Icon(Icons.monetization_on),
                label: Text('دفتر الديون / الكريديت'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business),
                label: Text('الشركات والموردين'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.hourglass_empty_outlined),
                selectedIcon: Icon(Icons.hourglass_full),
                label: Text('قائمة الانتظار والنواقص'),
              ),
              NavigationDrawerDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('التقارير والإحصائيات'),
              ),
              Divider(indent: 12, endIndent: 12),
              NavigationDrawerDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('إعدادات النظام'),
              ),
            ],
          ),
          
          // Main WorkSpace Content View
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(child: _views[_selectedIndex]),
            ),
          ),
        ],
      ),
    );
  }
}