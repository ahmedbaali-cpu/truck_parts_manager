import 'package:flutter/material.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('لوحة التحكم وإعدادات النظام الأساسية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dark_mode, color: theme.colorScheme.secondary),
                        const SizedBox(width: 10),
                        const Text('مظهر النظام التفاعلي (Theme)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تبديل وضع الألوان بين النهاري والليلي السريع'),
                        Switch(
                          value: themeNotifier.value == ThemeMode.dark,
                          onChanged: (val) {
                            themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: theme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.g_translate, color: theme.colorScheme.secondary),
                        const SizedBox(width: 10),
                        const Text('لغة واجهة المستخدم الرسومية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => localeNotifier.value = const Locale('ar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localeNotifier.value.languageCode == 'ar' ? theme.colorScheme.primary : null,
                            foregroundColor: localeNotifier.value.languageCode == 'ar' ? Colors.white : null,
                          ),
                          child: const Text('العربية (Default)'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => localeNotifier.value = const Locale('en'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localeNotifier.value.languageCode == 'en' ? theme.colorScheme.primary : null,
                            foregroundColor: localeNotifier.value.languageCode == 'en' ? Colors.white : null,
                          ),
                          child: const Text('English'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => localeNotifier.value = const Locale('fr'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: localeNotifier.value.languageCode == 'fr' ? theme.colorScheme.primary : null,
                            foregroundColor: localeNotifier.value.languageCode == 'fr' ? Colors.white : null,
                          ),
                          child: const Text('Français'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}