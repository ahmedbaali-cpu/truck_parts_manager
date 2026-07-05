import 'dart:async';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:truck_parts_manager/database/db_helper.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allParts = [];
  List<Map<String, dynamic>> _searchResult = [];
  final List<Map<String, dynamic>> _cart = []; 

  final TextEditingController _searchController = TextEditingController();
  double _totalInvoice = 0.0;

  final FocusNode _pageFocusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPressTime;
  
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInventory();

    _pageFocusNode.addListener(() {
      if (_pageFocusNode.hasFocus) {
        _loadInventory();
      }
    });

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadInventorySilently();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pageFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    if (!mounted) return;
    final data = await _dbHelper.getProducts(); 
    if (!mounted) return;
    setState(() {
      _allParts = data;
      if (_searchController.text.isNotEmpty) {
        _searchParts(_searchController.text);
      } else {
        _searchResult = data;
      }
    });
  }

  Future<void> _loadInventorySilently() async {
    final data = await _dbHelper.getProducts(); 
    if (!mounted) return;
    setState(() {
      _allParts = data;
      if (_searchController.text.isNotEmpty) {
        _searchParts(_searchController.text);
      } else {
        _searchResult = data;
      }
    });
  }

  void _calculateTotal() {
    _totalInvoice = 0.0;
    for (var item in _cart) {
      _totalInvoice += (item['price'] * item['cart_qty']);
    }
  }

  void _handleScannedBarcode(String barcode, String lang) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final matchedPart = _allParts.firstWhere(
      (part) => part['reference'].toString().toLowerCase() == cleanBarcode.toLowerCase() || 
                (part['barcode'] ?? '').toString().toLowerCase() == cleanBarcode.toLowerCase(),
      orElse: () => {},
    );

    if (matchedPart.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'تنبيه: لم يتم العثور على أي قطعة بالرمز ($cleanBarcode) في المخزن!'
                : 'Attention: Aucune pièce trouvée avec le code ($cleanBarcode)!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    int stockQty = matchedPart['quantity'] ?? 0;
    if (stockQty <= 0) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'خطأ: نفذت كمية (${matchedPart['name']}) من المخزن تماماً!'
                : 'Error: (${matchedPart['name']}) is out of stock!'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    final int cartIndex = _cart.indexWhere((item) => item['id'] == matchedPart['id']);

    if (cartIndex != -1) { 
      int currentCartQty = _cart[cartIndex]['cart_qty'];
      if (currentCartQty >= stockQty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'ar'
                  ? 'لا يمكن إضافة المزيد! الكمية المطلوبة تجاوزت المتوفر بالمخزن لـ (${matchedPart['name']})'
                  : 'Cannot add more! Stock limit reached.'),
            backgroundColor: Colors.orange[800],
          ),
        );
        return;
      }

      setState(() {
        _cart[cartIndex]['cart_qty'] += 1;
        _calculateTotal();
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'تم زيادة كمية (${matchedPart['name']}) إلى الحالي: ${_cart[cartIndex]['cart_qty']}'
                : 'Updated quantity for (${matchedPart['name']})'),
          backgroundColor: Colors.teal[700],
          duration: const Duration(milliseconds: 1500),
        ),
      );
    } else {
      _addToCart(matchedPart);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'ar'
                ? 'تم إضافة قطعة جديدة: (${matchedPart['name']}) للفاتورة'
                : 'Added new item: (${matchedPart['name']}) to bill'),
          backgroundColor: Colors.green[700],
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }

  void _searchParts(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _searchResult = _allParts;
      } else {
        _searchResult = _allParts.where((part) {
          final ref = (part['reference'] ?? '').toString().toLowerCase();
          final name = (part['name'] ?? '').toString().toLowerCase();
          final brand = (part['brand'] ?? '').toString().toLowerCase();
          final barcode = (part['barcode'] ?? '').toString().toLowerCase();
          return ref.contains(query.toLowerCase()) ||
              name.contains(query.toLowerCase()) ||
              brand.contains(query.toLowerCase()) || 
              barcode == query.toLowerCase();
        }).toList();
      }
    });
  }

  void _addToCart(Map<String, dynamic> part) {
    int stockQty = part['quantity'] ?? 0;
    if (stockQty <= 0) return;

    final existingIndex = _cart.indexWhere((item) => item['id'] == part['id']);
    if (existingIndex != -1) {
      if (_cart[existingIndex]['cart_qty'] < stockQty) {
        setState(() {
          _cart[existingIndex]['cart_qty'] += 1;
          _calculateTotal();
        });
      }
      return;
    }
    setState(() {
      _cart.add({
        ...part,
        'cart_qty': 1,
        'price': (part['selling_price'] as num).toDouble(),
      });
      _calculateTotal();
    });
  }

  void _editPriceDialog(int index, String lang) {
    final TextEditingController priceController = TextEditingController(text: _cart[index]['price'].toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(lang == 'ar' ? 'تعديل السعر المفرّد' : 'Edit Unit Price', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: lang == 'ar' ? 'السعر الجديد' : 'New Price',
              suffixText: 'DA',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(lang == 'ar' ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
              onPressed: () {
                final newPrice = double.tryParse(priceController.text);
                if (newPrice != null) {
                  setState(() {
                    _cart[index]['price'] = newPrice;
                    _calculateTotal();
                  });
                }
                Navigator.pop(context);
              },
              child: Text(lang == 'ar' ? 'حفظ' : 'Save'),
            )
          ],
        );
      }
    );
  }

  Future<void> _checkout(String lang) async {
    if (_cart.isEmpty) return;
    
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final String invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}';
    String dateStr = now.toString().split(' ')[0];

    List<String> lowStockAlerts = [];

    for (var item in _cart) {
      int qty = item['cart_qty'];
      double price = item['price'];

      await db.insert('sales', {
        'invoice_number': invoiceNumber,
        'product_id': item['id'],
        'product_name': item['name'],
        'quantity': qty,
        'selling_price': price,
        'date': dateStr,
      });

      await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?', [qty, item['id']]);

      final updated = await db.query('products', where: 'id = ?', whereArgs: [item['id']]);
      if (updated.isNotEmpty) {
        int remaining = int.tryParse(updated.first['quantity']?.toString() ?? '0') ?? 0;
        if (remaining <= 3) {
          lowStockAlerts.add('• ${item['name']} (الباقي: $remaining)'); 
        }
      }
    }

    final pdfBytes = await _generatePdfBytes(invoiceNumber, _cart, _totalInvoice);
    if (mounted) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Facture_$invoiceNumber.pdf',
      );
    }

    setState(() {
      _cart.clear();
      _totalInvoice = 0.0;
      _searchController.clear();
    });
    _loadInventorySilently();

    if (lowStockAlerts.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
              const SizedBox(width: 10),
              Text(lang == 'ar' ? 'تنبيه نقص المخزون!' : 'Low Stock Alert!', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            lang == 'ar' 
            ? 'انخفض مخزون القطع التالية إلى (3) أو أقل بعد هذه المبيعة:\n\n${lowStockAlerts.join('\n')}\n\nيرجى مراجعة قائمة تنبيهات المخزون لطلبها قريباً.'
            : 'The following items dropped to 3 or below after this sale:\n\n${lowStockAlerts.join('\n')}\n\nPlease check the Low Stock Alerts page.',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context),
              child: Text(lang == 'ar' ? 'حسناً، فهمت' : 'Understood', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
      );
    }
  }

  Future<void> _showPreview(String lang) async {
    if (_cart.isEmpty) return;
    final now = DateTime.now();
    final String dummyPreviewNumber = 'INV-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')} (DRAFT)';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ar' ? 'معاينة الفاتورة قبل الطباعة' : 'Invoice Preview',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 650,
            child: PdfPreview(
              build: (format) => _generatePdfBytes(dummyPreviewNumber, _cart, _totalInvoice),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: true,
              canChangePageFormat: true,
              canDebug: false,
            ),
          ),
        );
      }
    );
  }

  Future<Uint8List> _generatePdfBytes(String invoiceNumber, List<Map<String, dynamic>> items, double total) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pw.MemoryImage? watermarkImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/logo.png');
      watermarkImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Watermark not found: $e");
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              if (watermarkImage != null)
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.15,
                      child: pw.Image(watermarkImage, width: 250),
                    ),
                  ),
                ),
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('TRUCK PARTS PRO', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                            pw.Text('Vente de pieces detachees', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                          ]
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.grey400)
                          ),
                          child: pw.Text('FACTURE DE VENTE', style: pw.TextStyle(font: fontBold, fontSize: 14)), 
                        ),
                      ]
                    ),
                    pw.SizedBox(height: 15),
                    pw.Divider(color: PdfColors.grey400, thickness: 1), 
                    pw.SizedBox(height: 10),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Client: Comptoir (Vente Directe)', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Ref: $invoiceNumber', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                            pw.Text('Date: ${DateTime.now().toString().substring(0, 16)}', style: pw.TextStyle(font: font, fontSize: 12)),
                          ]
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 20),

                    pw.Expanded(
                      child: pw.TableHelper.fromTextArray(
                        headers: ['Designation', 'Ref', 'Qte', 'Prix U', 'Total'],
                        headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                        cellStyle: pw.TextStyle(font: font, fontSize: 10),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                        cellAlignments: {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.centerLeft,
                          2: pw.Alignment.center,     
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.centerRight,
                        },
                        data: items.map((item) {
                          int q = item['cart_qty'];
                          double price = item['price'];
                          return [
                            item['name'] ?? '',
                            item['reference'] ?? '',
                            '$q',
                            price.toStringAsFixed(2),
                            (q * price).toStringAsFixed(2)
                          ];
                        }).toList(),
                      ),
                    ),

                    pw.SizedBox(height: 15),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            border: pw.Border.all(color: PdfColors.black, width: 1.5),
                          ),
                          child: pw.Text('TOTAL: ${total.toStringAsFixed(2)} DA', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                        )
                      ]
                    ),
                    pw.SizedBox(height: 15),
                    pw.Center(
                      child: pw.Text('Merci pour votre visite / Thank you for your business', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                    )
                  ]
                )
              )
            ]
          );
        }
      )
    );
    return doc.save();
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'نقطة البيع (الفوترة)',
        'search': 'ابحث أو امسح باركود القطعة...',
        'cart_title': 'عناصر الفاتورة',
        'empty_cart': 'الفاتورة فارغة. قم بمسح باركود أو إضافة قطع.',
        'total': 'الإجمالي المطلوب دفعه:',
        'btn_confirm': 'تأكيد وطباعة (Enter)',
        'btn_preview': 'معاينة الفاتورة 👁️',
        'col_ref': 'المرجع',
        'col_name': 'اسم القطعة',
        'col_price': 'سعر الوحدة',
        'col_qty': 'الكمية',
        'col_subtotal': 'المجموع الفرعي',
        'col_action': 'إجراء',
        'edit_price': 'تعديل السعر',
      },
      'en': {
        'title': 'Point of Sale (POS)',
        'search': 'Search or scan barcode...',
        'cart_title': 'Invoice Items',
        'empty_cart': 'Cart is empty. Scan a barcode or add items.',
        'total': 'Total Payable:',
        'btn_confirm': 'Checkout & Print (Enter)',
        'btn_preview': 'Preview Invoice 👁️',
        'col_ref': 'Ref',
        'col_name': 'Part Name',
        'col_price': 'Unit Price',
        'col_qty': 'Qty',
        'col_subtotal': 'Subtotal',
        'col_action': 'Action',
        'edit_price': 'Edit Price',
      },
      'fr': {
        'title': 'Point de Vente (Facturation)',
        'search': 'Rechercher ou scanner le code à barre de la pièce...',
        'cart_title': 'Articles de la Facture',
        'empty_cart': 'Facture vide. Scannez un code à barre ou ajoutez des pièces.',
        'total': 'Total Général à Payer:',
        'btn_confirm': 'Valider & Imprimer (Entrée)',
        'btn_preview': 'Aperçu Bon 👁️',
        'col_ref': 'Réf',
        'col_name': 'Désignation',
        'col_price': 'Prix Unitaire',
        'col_qty': 'Quantité',
        'col_subtotal': 'Sous-total',
        'col_action': 'Action',
        'edit_price': 'Modifier le prix (Négocier)',
      }
    };
    return tx[lang]?[key] ?? tx['en']![key]!;
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = Localizations.localeOf(context).languageCode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const String currency = 'DA';

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
                _handleScannedBarcode(_barcodeBuffer, currentLang);
                _barcodeBuffer = '';
              } else if (_cart.isNotEmpty) {
                _checkout(currentLang);
              }
            } else if (character != null) {
              _barcodeBuffer += character;
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // قسم البحث والمنتجات (يسار)
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: _searchParts,
                      decoration: InputDecoration(
                        hintText: _getTxt('search', currentLang),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A2A3A) : Colors.white,
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
                        child: ListView.separated(
                          itemCount: _searchResult.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final part = _searchResult[index];
                            int qty = int.tryParse(part['quantity']?.toString() ?? '0') ?? 0;
                            return ListTile(
                              leading: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent),
                              ),
                              title: Text(part['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Ref: ${part['reference']} • ${currentLang == 'ar' ? 'المخزون: ' : (currentLang == 'fr' ? 'Stock: ' : 'Stock: ')}$qty'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${part['selling_price']} $currency', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0087B7))),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    onPressed: qty <= 0 ? null : () => _addToCart(part),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0087B7),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                    child: const Icon(Icons.add_shopping_cart, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              
              // قسم الفاتورة والدفع (يمين)
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF0087B7).withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                        width: double.infinity,
                        child: Text(_getTxt('cart_title', currentLang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0087B7))),
                      ),
                      Expanded(
                        child: _cart.isEmpty
                            ? Center(child: Text(_getTxt('empty_cart', currentLang), style: const TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                itemCount: _cart.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _cart[index];
                                  return ListTile(
                                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${item['price']} $currency x ${item['cart_qty']}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('${(item['price'] * item['cart_qty']).toStringAsFixed(2)} $currency', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                          onPressed: () => _editPriceDialog(index, currentLang),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              _cart.removeAt(index);
                                              _calculateTotal();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getTxt('total', currentLang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('${_totalInvoice.toStringAsFixed(2)} $currency', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    onPressed: _cart.isEmpty ? null : () => _showPreview(currentLang),
                                    icon: const Icon(Icons.remove_red_eye),
                                    label: Text(_getTxt('btn_preview', currentLang)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton.icon(
                                    onPressed: _cart.isEmpty ? null : () => _checkout(currentLang),
                                    icon: const Icon(Icons.print, size: 20),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey[300],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0,
                                    ),
                                    label: Text(_getTxt('btn_confirm', currentLang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}