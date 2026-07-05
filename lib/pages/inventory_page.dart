import 'dart:io'; // مطلوب للتعامل مع ملفات الصور
import 'package:file_picker/file_picker.dart'; // مكتبة اختيار الملفات
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allParts = [];
  List<Map<String, dynamic>> _filteredParts = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  int _totalTypes = 0;
  double _totalProfit = 0.0;
  double _totalValue = 0.0;

  final FocusNode _pageFocusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPressTime;

  @override
  void initState() {
    super.initState();
    _refreshInventory();
    
    _pageFocusNode.addListener(() {
      if (_pageFocusNode.hasFocus) {
        _refreshInventory();
      }
    });
  }

  @override
  void dispose() {
    _pageFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshInventory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await _dbHelper.getProducts(); 
    if (!mounted) return;
    setState(() {
      _allParts = data;
      _filteredParts = data;
      _calculateStatistics();
      _isLoading = false;
    });
    if (_searchController.text.isNotEmpty) {
      _filterInventory(_searchController.text);
    }
  }

  void _calculateStatistics() {
    _totalTypes = _allParts.length;
    _totalProfit = 0.0;
    _totalValue = 0.0;
    for (var part in _allParts) {
      int qty = part['quantity'] ?? 0;
      double buy = (part['buying_price'] as num?)?.toDouble() ?? 0.0;
      double sell = (part['selling_price'] as num?)?.toDouble() ?? 0.0;
      _totalValue += (sell * qty);
      _totalProfit += ((sell - buy) * qty);
    }
  }

  void _filterInventory(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredParts = _allParts;
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredParts = _allParts.where((part) {
          final name = (part['name'] ?? '').toString().toLowerCase();
          final reference = (part['reference'] ?? '').toString().toLowerCase();
          final brand = (part['brand'] ?? '').toString().toLowerCase();
          return name.contains(lowercaseQuery) || reference.contains(lowercaseQuery) || brand.contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  // النافذة المنبثقة لعرض الصورة الحقيقية للمنتج
  void _showPartImageDialog(Map<String, dynamic> part, String lang) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final String? imagePath = part['image_path'];
        final bool hasImage = imagePath != null && File(imagePath).existsSync();

        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            part['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                clipBehavior: Clip.antiAlias, // مهم لقص حواف الصورة بشكل دائري حسب الحاوية
                child: hasImage 
                  ? Image.file(File(imagePath!), fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            lang == 'ar' 
                                ? 'لا توجد صورة مسجلة لهذه القطعة حالياً.' 
                                : (lang == 'fr' ? 'Aucune photo disponible pour cette pièce.' : 'No photo available for this part.'),
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
              ),
              const SizedBox(height: 12),
              Text('${part['reference']} • ${part['brand'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: Text(lang == 'ar' ? 'إغلاق' : (lang == 'fr' ? 'Fermer' : 'Close')),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddOrEditDialog({Map<String, dynamic>? item, required String lang}) {
    final bool isEdit = item != null;
    final formKey = GlobalKey<FormState>();

    final refController = TextEditingController(text: isEdit ? item['reference'] : '');
    final nameController = TextEditingController(text: isEdit ? item['name'] : '');
    final brandController = TextEditingController(text: isEdit ? item['brand'] : '');
    final shelfController = TextEditingController(text: isEdit ? item['shelf'] : '');
    final buyController = TextEditingController(text: isEdit ? item['buying_price'].toString() : '');
    final sellController = TextEditingController(text: isEdit ? item['selling_price'].toString() : '');
    final qtyController = TextEditingController(text: isEdit ? item['quantity'].toString() : '');

    // متغير لحفظ مسار الصورة المحددة
    String? selectedImagePath = isEdit ? item['image_path'] : null;

    String title = isEdit ? 'Edit Spare Part' : 'Add New Spare Part';
    String labelRef = 'Reference Code';
    String labelName = 'Part Title Name';
    String labelBrand = 'Brand / Maker';
    String labelShelf = 'Shelf Location';
    String labelBuy = 'Purchase Price';
    String labelSell = 'Selling Price';
    String labelQty = 'Stock Quantity';
    String btnSave = 'Save Changes';
    String btnCancel = 'Cancel';
    String valRequired = 'Required Field';
    String valNumber = 'Enter valid value';

    if (lang == 'ar') {
      title = isEdit ? 'تعديل قطعة غيار' : 'إضافة قطعة غيار جديدة';
      labelRef = 'رمز القطعة (Référence)';
      labelName = 'اسم قطعة الغيار';
      labelBrand = 'الماركة / العلامة التجارية';
      labelShelf = 'مكان التخزين (الرف)';
      labelBuy = 'سعر الشراء';
      labelSell = 'سعر البيع المقترح';
      labelQty = 'الكمية المتوفرة بالمخزن';
      btnSave = 'حفظ البيانات';
      btnCancel = 'إلغاء الأمر';
      valRequired = 'حقل مطلوب';
      valNumber = 'الرجاء إدخال رقم صحيح';
    } else if (lang == 'fr') {
      title = isEdit ? 'Modifier la Pièce' : 'Ajouter une Pièce';
      labelRef = 'Code Référence';
      labelName = 'Nom de la Pièce';
      labelBrand = 'Marque / Fabricant';
      labelShelf = 'Rayon / Étagère';
      labelBuy = 'Prix d\'Achat';
      labelSell = 'Prix de Vente';
      labelQty = 'Quantité en Stock';
      btnSave = 'Enregistrer';
      btnCancel = 'Annuler';
      valRequired = 'Champ obligatoire';
      valNumber = 'Valeur numérique invalide';
    }

    showDialog(
      context: context,
      builder: (context) {
        // نستخدم StatefulBuilder لكي نستطيع تحديث واجهة المربع عند اختيار صورة
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final bool hasImage = selectedImagePath != null && File(selectedImagePath!).existsSync();

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- زر رفع وإضافة الصورة ---
                      GestureDetector(
                        onTap: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );

                          if (result != null) {
                            setDialogState(() {
                              selectedImagePath = result.files.single.path;
                            });
                          }
                        },
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasImage
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(File(selectedImagePath!), fit: BoxFit.cover),
                                    Container(color: Colors.black45), // طبقة تعتيم
                                    const Center(child: Icon(Icons.edit, color: Colors.white, size: 32)),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.blue[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      lang == 'ar' ? 'إضغط لاختيار صورة (اختياري)' : 'Click to select photo',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ---------------------------

                      TextFormField(
                        controller: refController,
                        autofocus: true, 
                        decoration: InputDecoration(
                          labelText: labelRef,
                          suffixIcon: const Icon(Icons.qr_code_scanner, size: 20, color: Colors.grey),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? valRequired : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: labelName),
                        validator: (v) => v == null || v.trim().isEmpty ? valRequired : null,
                      ),
                      TextFormField(controller: brandController, decoration: InputDecoration(labelText: labelBrand)),
                      TextFormField(controller: shelfController, decoration: InputDecoration(labelText: labelShelf)),
                      TextFormField(
                        controller: buyController,
                        decoration: InputDecoration(labelText: labelBuy),
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? valNumber : null,
                      ),
                      TextFormField(
                        controller: sellController,
                        decoration: InputDecoration(labelText: labelSell),
                        keyboardType: TextInputType.number,
                        validator: (v) => double.tryParse(v ?? '') == null ? valNumber : null,
                      ),
                      TextFormField(
                        controller: qtyController,
                        decoration: InputDecoration(labelText: labelQty),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null ? valNumber : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final String currentRef = refController.text.trim();
                      final existingPart = _allParts.firstWhere(
                        (part) => part['reference'].toString().toLowerCase() == currentRef.toLowerCase(),
                        orElse: () => {},
                      );

                      // إذا كنا في وضع الإضافة، وتم مسح منتج موجود مسبقاً، نقوم بتحديث تراكمي للكمية
                      if (!isEdit && existingPart.isNotEmpty) {
                        int currentQty = existingPart['quantity'] ?? 0;
                        int newAddedQty = int.parse(qtyController.text.trim());
                        
                        final Map<String, dynamic> row = {
                          'reference': currentRef,
                          'name': nameController.text.trim(),
                          'brand': brandController.text.trim(),
                          'shelf': shelfController.text.trim(),
                          'buying_price': double.parse(buyController.text.trim()),
                          'selling_price': double.parse(sellController.text.trim()),
                          'quantity': currentQty + newAddedQty, 
                          'image_path': selectedImagePath, // حفظ مسار الصورة
                        };
                        
                        row['id'] = existingPart['id'];
                        await _dbHelper.updateProduct(row); 
                        
                      } else {
                        final Map<String, dynamic> row = {
                          'reference': currentRef,
                          'name': nameController.text.trim(),
                          'brand': brandController.text.trim(),
                          'shelf': shelfController.text.trim(),
                          'buying_price': double.parse(buyController.text.trim()),
                          'selling_price': double.parse(sellController.text.trim()),
                          'quantity': int.parse(qtyController.text.trim()),
                          'image_path': selectedImagePath, // حفظ مسار الصورة
                        };

                        if (isEdit) {
                          row['id'] = item['id'];
                          await _dbHelper.updateProduct(row);
                        } else {
                          await _dbHelper.insertProduct(row);
                        }
                      }
                      if (context.mounted) Navigator.pop(context);
                      _refreshInventory();
                    }
                  },
                  child: Text(btnSave),
                )
              ],
            );
          }
        );
      },
    );
  }

  void _showDeleteConfirmation(int id, String name, String lang) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(lang == 'ar' ? 'تأكيد الحذف' : (lang == 'fr' ? 'Confirmer la suppression' : 'Confirm Delete')),
          content: Text(lang == 'ar' 
              ? 'هل أنت متأكد من حذف "$name" من قاعدة بيانات السلع تماماً؟' 
              : (lang == 'fr' ? 'Voulez-vous supprimer "$name" définitivement?' : 'Are you sure you want to delete "$name" from the records?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang == 'ar' ? 'إلغاء' : (lang == 'fr' ? 'Annuler' : 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await _dbHelper.deleteProduct(id);
                if (context.mounted) Navigator.pop(context);
                _refreshInventory();
              },
              child: Text(lang == 'ar' ? 'حذف نهائي' : (lang == 'fr' ? 'Supprimer' : 'Delete')),
            )
          ],
        );
      },
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'مخزن قطع الغيار والسلع المتوفرة',
        'search': 'ابحث عن قطعة عبر الاسم، الرمز أو الماركة...',
        'add_item': 'إضافة سلعة للمخزن',
        'stat_types': 'أنواع السلع الفريدة',
        'stat_value': 'إجمالي قيمة البيع المتوقعة',
        'stat_profit': 'الأرباح التقديرية المخزونة',
        'col_ref': 'الرمز مرجع',
        'col_name': 'اسم القطعة',
        'col_brand': 'الماركة',
        'col_shelf': 'الرف',
        'col_buy': 'سعر الشراء',
        'col_sell': 'سعر البيع',
        'col_qty': 'المخزون',
        'col_actions': 'إجراءات',
        'empty': 'لا يوجد سلع تطابق بحثك حالياً.',
        'tooltip_photo': 'عرض صورة القطعة',
      },
      'en': {
        'title': 'Inventory Stock Management',
        'search': 'Search inventory by name, code or brand manufacturer...',
        'add_item': 'Add New Product',
        'stat_types': 'Unique Stock Items',
        'stat_value': 'Total Expected Market Value',
        'stat_profit': 'Total Stock Profit Margin',
        'col_ref': 'Reference',
        'col_name': 'Item Title',
        'col_brand': 'Brand',
        'col_shelf': 'Shelf',
        'col_buy': 'Buying Cost',
        'col_sell': 'Selling Price',
        'col_qty': 'Stock Qty',
        'col_actions': 'Actions',
        'empty': 'No matching stock records found.',
        'tooltip_photo': 'View Photo',
      },
      'fr': {
        'title': 'Gestion du Stock & Inventaire',
        'search': 'Rechercher par désignation, référence ou fabricant...',
        'add_item': 'Ajouter une Pièce',
        'stat_types': 'Articles Uniques',
        'stat_value': 'Valeur Marchande Totale',
        'stat_profit': 'Marge Bénéficiaire Estimée',
        'col_ref': 'Référence',
        'col_name': 'Désignation',
        'col_brand': 'Marque',
        'col_shelf': 'Rayon',
        'col_buy': 'Prix d\'Achat',
        'col_sell': 'Prix de Vente',
        'col_qty': 'Quantité Stock',
        'col_actions': 'Actions',
        'empty': 'Aucun produit trouvé dans le stock.',
        'tooltip_photo': 'Voir la photo',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const String currency = 'DA';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageFocusNode.hasFocus && ModalRoute.of(context)?.isCurrent == true) {
        FocusScope.of(context).requestFocus(_pageFocusNode);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: KeyboardListener(
        focusNode: _pageFocusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            final String? character = event.character;
            final now = DateTime.now();

            if (_lastKeyPressTime == null || now.difference(_lastKeyPressTime!).inMilliseconds > 50) {
              _barcodeBuffer = '';
            }
            _lastKeyPressTime = now;

            if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (_barcodeBuffer.trim().isNotEmpty) {
                _searchController.text = _barcodeBuffer.trim();
                _filterInventory(_barcodeBuffer.trim());
                _barcodeBuffer = '';
              }
            } else if (character != null) {
              _barcodeBuffer += character;
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _refreshInventory,
                        icon: const Icon(Icons.refresh, size: 24, color: Color(0xFF0087B7)),
                        tooltip: currentLang == 'ar' ? 'تحديث المخزن' : 'Refresh Inventory',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrEditDialog(lang: currentLang),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0087B7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: Text(_getTxt('add_item', currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  _buildSummaryCard(_getTxt('stat_types', currentLang), '$_totalTypes', Icons.category_outlined, isDark),
                  const SizedBox(width: 16),
                  _buildSummaryCard(_getTxt('stat_value', currentLang), '$_totalValue $currency', Icons.monetization_on_outlined, isDark, iconColor: Colors.teal),
                  const SizedBox(width: 16),
                  _buildSummaryCard(_getTxt('stat_profit', currentLang), '$_totalProfit $currency', Icons.trending_up_outlined, isDark, iconColor: Colors.green),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _searchController,
                onChanged: _filterInventory,
                decoration: InputDecoration(
                  hintText: _getTxt('search', currentLang),
                  prefixIcon: const Icon(Icons.search),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF0087B7)))
                      : _filteredParts.isEmpty
                          ? Center(child: Text(_getTxt('empty', currentLang), style: const TextStyle(color: Colors.grey)))
                          : Scrollbar(
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: DataTable(
                                          dataRowMaxHeight: 70.0,
                                          headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
                                          columnSpacing: 24.0,
                                          columns: [
                                            DataColumn(label: Text(_getTxt('col_ref', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_name', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_brand', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_shelf', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_buy', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_sell', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_qty', currentLang))),
                                            DataColumn(label: Text(_getTxt('col_actions', currentLang))),
                                          ],
                                          rows: _filteredParts.map((part) {
                                            int qty = part['quantity'] ?? 0;
                                            bool lowStock = qty <= 3;
                                            return DataRow(cells: [
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 110),
                                                  child: Text(
                                                    part['reference'] ?? '',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                SizedBox(
                                                  width: 200, 
                                                  child: Text(
                                                    part['name'] ?? '',
                                                    softWrap: true, 
                                                    maxLines: 2, 
                                                    overflow: TextOverflow.ellipsis, 
                                                    style: const TextStyle(height: 1.2), 
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 100),
                                                  child: Text(
                                                    part['brand'] ?? '-',
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 90),
                                                  child: Text(
                                                    part['shelf'] ?? '-',
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text('${part['buying_price']} $currency')),
                                              DataCell(Text('${part['selling_price']} $currency', style: const TextStyle(color: Color(0xFF0087B7), fontWeight: FontWeight.bold))),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: lowStock ? Colors.red.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '$qty',
                                                    style: TextStyle(
                                                      color: lowStock ? Colors.redAccent : Colors.green,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.image_outlined, color: Colors.blueAccent, size: 18),
                                                      tooltip: _getTxt('tooltip_photo', currentLang),
                                                      onPressed: () => _showPartImageDialog(part, currentLang),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, color: Colors.amber, size: 18),
                                                      onPressed: () => _showAddOrEditDialog(item: part, lang: currentLang),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline_outlined, color: Colors.redAccent, size: 18),
                                                      onPressed: () => _showDeleteConfirmation(part['id'], part['name'] ?? '', currentLang),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ]);
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, bool isDark, {Color iconColor = const Color(0xFF0087B7)}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}