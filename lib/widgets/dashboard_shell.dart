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
import 'package:truck_parts_manager/pages/expenses_page.dart'; // ADDED
import 'package:truck_parts_manager/pages/workers_page.dart';   // ADDED

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _selectedIndex = 0;

  // Fully updated views mapping containing all 10 pages in precise index order
  final List<Widget> _views = [
    const InventoryPage(),   // 0. المخزن
    const SalesPage(),       // 1. المبيعات
    const ReturnsPage(),     // 2. المرتجعات
    const CreditPage(),      // 3. الديون
    const CompaniesPage(),   // 4. الشركات
    const ExpensesPage(),    // 5. المصاريف المصاحبة
    const WorkersPage(),     // 6. إدارة العمال
    const WaitingListPage(), // 7. قائمة الانتظار
    const ReportsPage(),     // 8. التقارير
    const SettingsPage(),    // 9. الإعدادات
  ];

  // Localization function supporting Arabic, English, and French
  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'لوحة التحكم',
        'nav_inventory': 'المخزن والمستودع',
        'nav_sales': 'قسم المبيعات السريعة',
        'nav_returns': 'إدارة المرتجعات',
        'nav_credit': 'دفتر الديون / الكريديت',
        'nav_companies': 'الشركات والموردين',
        'nav_expenses': 'إدارة المصاريف والنفقات',
        'nav_workers': 'إدارة شؤون العمال',
        'nav_waiting': 'قائمة الانتظار والنواقص',
        'nav_reports': 'التقارير والإحصائيات',
        'nav_settings': 'إعدادات النظام',
      },
      'en': {
        'title': 'Dashboard Panel',
        'nav_inventory': 'Inventory & Stock',
        'nav_sales': 'Quick Sales Counter',
        'nav_returns': 'Returns Management',
        'nav_credit': 'Credit & Debts Ledger',
        'nav_companies': 'Companies & Suppliers',
        'nav_expenses': 'Expenses & Outgoings',
        'nav_workers': 'Staff & Workers Management',
        'nav_waiting': 'Waiting List & Shortages',
        'nav_reports': 'Reports & Analytics',
        'nav_settings': 'System Settings',
      },
      'fr': {
        'title': 'Tableau de bord',
        'nav_inventory': 'Inventaire & Stock',
        'nav_sales': 'Comptoir de Ventes',
        'nav_returns': 'Gestion des Retours',
        'nav_credit': 'Registre des Crédits',
        'nav_companies': 'Sociétés & Fournisseurs',
        'nav_expenses': 'Frais & Dépenses',
        'nav_workers': 'Gestion des Employés',
        'nav_waiting': 'Liste d\'attente & Manques',
        'nav_reports': 'Rapports & Statistiques',
        'nav_settings': 'Paramètres Système',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key]!;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation Drawer Layout
          NavigationDrawer(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
                child: Text(
                  _getTxt('title', currentLang),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2),
                label: Text(_getTxt('nav_inventory', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.point_of_sale_outlined),
                selectedIcon: const Icon(Icons.point_of_sale),
                label: Text(_getTxt('nav_sales', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.assignment_return_outlined),
                selectedIcon: const Icon(Icons.assignment_return),
                label: Text(_getTxt('nav_returns', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.monetization_on_outlined),
                selectedIcon: const Icon(Icons.monetization_on),
                label: Text(_getTxt('nav_credit', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.business_outlined),
                selectedIcon: const Icon(Icons.business),
                label: Text(_getTxt('nav_companies', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: const Icon(Icons.account_balance_wallet),
                label: Text(_getTxt('nav_expenses', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.badge_outlined),
                selectedIcon: const Icon(Icons.badge),
                label: Text(_getTxt('nav_workers', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.hourglass_empty_outlined),
                selectedIcon: const Icon(Icons.hourglass_full),
                label: Text(_getTxt('nav_waiting', currentLang)),
              ),
              NavigationDrawerDestination(
                icon: const Icon(Icons.analytics_outlined),
                selectedIcon: const Icon(Icons.analytics),
                label: Text(_getTxt('nav_reports', currentLang)),
              ),
              const Divider(indent: 12, endIndent: 12),
              NavigationDrawerDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(_getTxt('nav_settings', currentLang)),
              ),
            ],
          ),
          
          // Main WorkSpace Content View
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _views,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}