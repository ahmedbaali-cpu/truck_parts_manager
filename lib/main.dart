import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:truck_parts_manager/widgets/dashboard_shell.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('ar'));

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  runApp(const TruckPartsApp());
}

class TruckPartsApp extends StatelessWidget {
  const TruckPartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (_, currentLocale, __) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'نظام إدارة قطع الشاحنات الاحترافي',
              themeMode: currentMode,
              locale: currentLocale,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('ar'),
                Locale('en'),
                Locale('fr'),
              ],
              theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFFF8FAFC), 
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0F172A), 
                  primary: const Color(0xFF1E293B),   
                  secondary: const Color(0xFF0D9488), 
                  surface: Colors.white,
                  brightness: Brightness.light,
                ),
                fontFamily: 'Segoe UI',
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF0F172A), 
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF0F172A), 
                  primary: const Color(0xFF1E293B),   
                  secondary: const Color(0xFF0D9488), 
                  surface: const Color(0xFF1E293B),
                  brightness: Brightness.dark,
                ),
                fontFamily: 'Segoe UI',
              ),
              home: DashboardShell(),
            );
          },
        );
      },
    );
  }
}