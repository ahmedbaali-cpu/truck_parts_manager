import 'package:flutter/material.dart';
import 'package:truck_parts_manager/main.dart'; // للوصول لدالة تحويل المظهر وتغيير اللغة

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // دالة مساعدة لترجمة نصوص صفحة الإعدادات بالكامل
  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'إعدادات النظام',
        'theme_title': 'المظهر الداكن (Dark Mode)',
        'theme_desc': 'تغيير مظهر التطبيق بالكامل لحماية العين وتقليل استهلاك الطاقة.',
        'lang_title': 'لغة النظام والتطبيق',
        'lang_desc': 'اختر اللغة المفضلة لواجهات التطبيق (يتم التطبيق فوراً).',
        'lang_ar': 'العربية (Arabic)',
        'lang_en': 'English',
        'lang_fr': 'Français (French)',
      },
      'en': {
        'title': 'System Settings',
        'theme_title': 'Dark Mode',
        'theme_desc': 'Switch the entire application appearance to protect your eyes.',
        'lang_title': 'System Language',
        'lang_desc': 'Select your preferred language for the application interfaces.',
        'lang_ar': 'العربية (Arabic)',
        'lang_en': 'English',
        'lang_fr': 'Français (French)',
      },
      'fr': {
        'title': 'Paramètres du Système',
        'theme_title': 'Mode Sombre',
        'theme_desc': 'Changer l\'apparence de l\'application pour protéger vos yeux.',
        'lang_title': 'Langue du Système',
        'lang_desc': 'Sélectionnez la langue préférée pour l\'interface.',
        'lang_ar': 'العربية (Arabic)',
        'lang_en': 'English',
        'lang_fr': 'Français (French)',
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
            Text(
              _getTxt('title', currentLang),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 1. خيار تبديل المظهر الداكن والفاتح
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    color: const Color(0xFF0087B7),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTxt('theme_title', currentLang),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTxt('theme_desc', currentLang),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    activeColor: const Color(0xFF0087B7),
                    onChanged: (value) {
                      // تحديث الـ ValueNotifier لتغيير المظهر فوراً عبر التطبيق بالكامل
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. خيار تغيير لغة التطبيق
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.translate_outlined,
                    color: const Color(0xFF0087B7),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTxt('lang_title', currentLang),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTxt('lang_desc', currentLang),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentLang,
                      dropdownColor: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'ar',
                          child: Text(_getTxt('lang_ar', currentLang)),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(_getTxt('lang_en', currentLang)),
                        ),
                        DropdownMenuItem(
                          value: 'fr',
                          child: Text(_getTxt('lang_fr', currentLang)),
                        ),
                      ],
                      onChanged: (String? newLang) {
                        if (newLang != null && newLang != currentLang) {
                          // تحديث الـ ValueNotifier لتغيير لغة التطبيق فوراً والاتجاه الصحيح للواجهة
                          localeNotifier.value = Locale(newLang);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}