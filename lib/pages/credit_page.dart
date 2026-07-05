import 'dart:async'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truck_parts_manager/database/db_helper.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CreditPage extends StatefulWidget {
  const CreditPage({super.key});

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allCredits = [];
  List<Map<String, dynamic>> _filteredCredits = [];
  bool _isLoading = true;

  double _totalOutDebt = 0.0;
  final TextEditingController _searchController = TextEditingController();
  
  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    _refreshCredits();
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCredits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await _dbHelper.getCustomers(); 
    if (!mounted) return;
    setState(() {
      _allCredits = data;
      _filteredCredits = data;
      _calculateTotalDebt();
      _isLoading = false;
    });
  }

  void _calculateTotalDebt() {
    _totalOutDebt = 0.0;
    for (var credit in _allCredits) {
      _totalOutDebt += (credit['debt'] as num?)?.toDouble() ?? 0.0;
    }
  }

  void _filterCredits(String query) {
    if (_debounceSearch?.isActive ?? false) _debounceSearch!.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filteredCredits = _allCredits.where((credit) {
          final name = (credit['name'] ?? '').toString().toLowerCase();
          final phone = (credit['phone'] ?? '').toString();
          return name.contains(query.toLowerCase()) || phone.contains(query);
        }).toList();
      });
    });
  }

  Future<void> _deleteCustomer(Map<String, dynamic> credit, String lang) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(lang == 'ar' ? 'حذف الزبون؟' : 'Delete Customer?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(lang == 'ar' 
          ? 'هل أنت متأكد من حذف الزبون (${credit['name']}) نهائياً؟ سيتم مسح كل ديونه والسلع التي أخذها من السجل.'
          : 'Are you sure you want to delete (${credit['name']})? All debts and items history will be erased.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang == 'ar' ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang == 'ar' ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final db = await _dbHelper.database;
      await db.rawDelete('DELETE FROM customer_items WHERE customer_id = ?', [credit['id']]);
      await db.rawDelete('DELETE FROM customers WHERE id = ?', [credit['id']]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'ar' ? 'تم الحذف بنجاح' : 'Deleted successfully'),
          backgroundColor: Colors.green,
        ));
      }
      _refreshCredits();
    }
  }

  void _showCreateDebtorDialog(BuildContext context, String lang) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String title = 'Open New Customer File';
    String labelName = 'Customer Name';
    String labelPhone = 'Phone Number';
    String valReq = 'Required';
    String btnCancel = 'Cancel';
    String btnCreate = 'Create';

    if (lang == 'ar') {
      title = 'فتح ملف زبون جديد';
      labelName = 'اسم الزبون / الشركة';
      labelPhone = 'رقم الهاتف';
      valReq = 'مطلوب';
      btnCancel = 'إلغاء';
      btnCreate = 'إنشاء';
    } else if (lang == 'fr') {
      title = 'Ouvrir un nouveau dossier client';
      labelName = 'Nom du client / Entreprise';
      labelPhone = 'Numéro de téléphone';
      valReq = 'Obligatoire';
      btnCancel = 'Annuler';
      btnCreate = 'Créer';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: labelName),
                validator: (v) => v!.isEmpty ? valReq : null,
              ),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: labelPhone),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _dbHelper.insertCustomer({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'debt': 0.0, 
                });
                if (context.mounted) Navigator.pop(context);
                _refreshCredits();
              }
            },
            child: Text(btnCreate),
          )
        ],
      ),
    );
  }

  // ========================================================
  // دالة تعديل سعر القطعة المباعة للزبون
  // ========================================================
  void _editItemPriceDialog(Map<String, dynamic> item, Map<String, dynamic> customer, String lang, VoidCallback onSaved) {
    final priceController = TextEditingController(text: item['price'].toString());
    final formKey = GlobalKey<FormState>();

    String title = 'Edit Total Price';
    String hint = 'New Total Price (DA)';
    String btnCancel = 'Cancel';
    String btnSave = 'Save';

    if (lang == 'ar') {
      title = 'تعديل السعر الإجمالي للقطعة';
      hint = 'السعر الجديد (DA)';
      btnCancel = 'إلغاء';
      btnSave = 'حفظ التعديل';
    } else if (lang == 'fr') {
      title = 'Modifier le prix total';
      hint = 'Nouveau prix (DA)';
      btnCancel = 'Annuler';
      btnSave = 'Enregistrer';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: priceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: hint, suffixText: 'DA'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid amount';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double newPrice = double.parse(priceController.text.trim());
                double oldPrice = (item['price'] as num).toDouble();
                double diff = newPrice - oldPrice; 

                final db = await _dbHelper.database;
                await db.rawUpdate('UPDATE customer_items SET price = ? WHERE id = ?', [newPrice, item['id']]);
                await db.rawUpdate('UPDATE customers SET debt = debt + ? WHERE id = ?', [diff, customer['id']]);

                if (context.mounted) Navigator.pop(context);
                onSaved(); 
              }
            },
            child: Text(btnSave),
          )
        ],
      ),
    );
  }

  // ========================================================
  // دالة إرجاع القطعة (حذفها من الزبون وإرجاعها للمخزن)
  // ========================================================
  void _returnItemToStockDialog(Map<String, dynamic> item, Map<String, dynamic> customer, String lang, VoidCallback onDeleted) {
    String title = 'Return Item to Stock?';
    String content = 'Are you sure you want to return this item? It will be removed from the customer bill, the debt will be reduced, and the quantity will be returned to your inventory.';
    String btnCancel = 'Cancel';
    String btnConfirm = 'Confirm Return';

    if (lang == 'ar') {
      title = 'إرجاع القطعة للمخزن؟';
      content = 'هل أنت متأكد من إرجاع هذه القطعة؟ سيتم حذفها من حساب الزبون وإنقاص دينه، وإعادة الكمية إلى المخزن الرئيسي لتتمكن من بيعها مجدداً.';
      btnCancel = 'إلغاء';
      btnConfirm = 'تأكيد الإرجاع';
    } else if (lang == 'fr') {
      title = 'Retourner l\'article au stock?';
      content = 'Êtes-vous sûr de vouloir retourner cet article ? Il sera supprimé de la facture, la dette sera réduite et la quantité sera remise en stock.';
      btnCancel = 'Annuler';
      btnConfirm = 'Confirmer le retour';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text(btnCancel, style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              final db = await _dbHelper.database;
              
              double itemPrice = (item['price'] as num).toDouble();
              int itemQty = (item['quantity'] as num).toInt();

              // 1. إنقاص الدين من الزبون
              await db.rawUpdate('UPDATE customers SET debt = debt - ? WHERE id = ?', [itemPrice, customer['id']]);
              
              // 2. إرجاع الكمية إلى المخزن
              if (item['product_id'] != null) {
                await db.rawUpdate('UPDATE products SET quantity = quantity + ? WHERE id = ?', [itemQty, item['product_id']]);
              } else {
                // خطة بديلة: إذا لم يكن معرف القطعة محفوظاً، يتم البحث عن طريق الاسم
                await db.rawUpdate('UPDATE products SET quantity = quantity + ? WHERE name = ?', [itemQty, item['product_name']]);
              }

              // 3. حذف السطر من سجل الزبون
              await db.rawDelete('DELETE FROM customer_items WHERE id = ?', [item['id']]);

              if (context.mounted) Navigator.pop(context);
              onDeleted(); // تحديث الواجهة بعد الانتهاء
            },
            child: Text(btnConfirm),
          )
        ],
      ),
    );
  }

  // ========================================================
  // توليد ملف الـ PDF الخاص بوصل الكريديت للزبون
  // ========================================================
  Future<Uint8List> _generateCreditPdfBytes(Map<String, dynamic> customer, List<Map<String, dynamic>> items, PdfPageFormat format) async {
    final doc = pw.Document();
    
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    pw.MemoryImage? watermarkImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/logo.png');
      watermarkImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Watermark not found: $e");
    }

    final String invoiceNumber = 'CRD-${customer['id']}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    double totalDebt = (customer['debt'] as num?)?.toDouble() ?? 0.0;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format, 
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          buildBackground: (context) {
            if (watermarkImage != null) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Center(
                  child: pw.Opacity(
                    opacity: 0.15,
                    child: pw.Image(watermarkImage, width: 300), 
                  ),
                ),
              );
            }
            return pw.Container();
          },
        ),
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        border: pw.Border.all(color: PdfColors.black, width: 1.5),
                      ),
                      child: pw.Text('TOTAL DETTE RESTE: ${totalDebt.toStringAsFixed(2)} DA', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    )
                  ]
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Signature du Client:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('Cachet / Signature:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  ]
                ),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TRUCK PARTS PRO', style: pw.TextStyle(font: fontBold, fontSize: 18)),
                    pw.Text('Vente de pieces detachees', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  ]
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey400)
                  ),
                  child: pw.Text('BON DE CREDIT / FACTURE', style: pw.TextStyle(font: fontBold, fontSize: 14)), 
                ),
              ]
            ),
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.grey400, thickness: 1), 
            pw.SizedBox(height: 15),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Client: ${customer['name']}', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                    if (customer['phone'] != null && customer['phone'].toString().isNotEmpty)
                      pw.Text('Tel: ${customer['phone']}', style: pw.TextStyle(font: font, fontSize: 12)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Ref: $invoiceNumber', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}', style: pw.TextStyle(font: font, fontSize: 12)),
                  ]
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Designation', 'Qte', 'Total (DA)'],
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 11),
              cellStyle: pw.TextStyle(font: font, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,     
                3: pw.Alignment.centerRight,
              },
              data: items.map((item) {
                String rawDate = item['date']?.toString() ?? '';
                String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
                double price = (item['price'] as num).toDouble();
                bool isPayment = price < 0; 
                
                return [
                  formattedDate,
                  item['product_name'],
                  isPayment ? '-' : '${item['quantity']}', 
                  price.toStringAsFixed(2) 
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  void _showInAppPreview(Map<String, dynamic> customer, List<Map<String, dynamic>> items, String lang) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ar' ? 'معاينة وصل الزبون' : 'Customer Bill Preview',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: 700, 
            height: 750, 
            child: PdfPreview(
              build: (format) => _generateCreditPdfBytes(customer, items, format),
              allowPrinting: true, 
              allowSharing: true,  
              canChangeOrientation: true, 
              canChangePageFormat: true,  
              canDebug: false, 
              pdfFileName: 'Credit_Bon_${customer['name']}.pdf',
            ),
          ),
        );
      },
    );
  }

  void _openCustomerFile(Map<String, dynamic> initialCredit, String lang) async {
    List<Map<String, dynamic>> items = await _dbHelper.getCustomerItems(initialCredit['id']);
    Map<String, dynamic> credit = Map.from(initialCredit);

    if (!mounted) return;

    String currentDebtText = 'Current Debt:';
    String addPartsText = 'Add Parts';
    String printBillText = 'Print / Preview';
    String partsTakenText = 'Parts Taken & Payments History:';
    String noPartsText = 'No records in this file yet.';

    if (lang == 'ar') {
      currentDebtText = 'إجمالي الدين الحالي:';
      addPartsText = 'إضافة سلع';
      printBillText = 'طباعة / معاينة';
      partsTakenText = 'سجل السلع المأخوذة والدفعات السابقة:';
      noPartsText = 'لم يتم تسجيل أي قطع أو دفعات في ملفه بعد.';
    } else if (lang == 'fr') {
      currentDebtText = 'Dette actuelle :';
      addPartsText = 'Ajouter';
      printBillText = 'Imprimer';
      partsTakenText = 'Historique des pièces et versements :';
      noPartsText = 'Aucun enregistrement dans ce dossier.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85, 
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(credit['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('$currentDebtText ${credit['debt'] ?? 0.0} DA', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(printBillText),
                            onPressed: items.isEmpty ? null : () {
                              _showInAppPreview(credit, items, lang);
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: Text(addPartsText),
                            onPressed: () {
                              Navigator.pop(context); 
                              _showStockSelectionModal(context, credit, lang);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 32),
                  Text(partsTakenText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Text(noPartsText))
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              
                              String rawDate = item['date']?.toString() ?? '';
                              String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
                              double price = (item['price'] ?? 0).toDouble();
                              bool isPayment = price < 0; 

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(
                                    isPayment ? Icons.payments : Icons.shopping_bag,
                                    color: isPayment ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(
                                    isPayment ? item['product_name'] : '${item['product_name']} (x${item['quantity']})', 
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                  subtitle: Text('Date: $formattedDate'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${price.toStringAsFixed(2)} DA', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          color: isPayment ? Colors.green : Colors.redAccent
                                        )
                                      ),
                                      if (!isPayment) ...[
                                        const SizedBox(width: 8),
                                        // زر تعديل السعر
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _editItemPriceDialog(item, credit, lang, () async {
                                              final newItems = await _dbHelper.getCustomerItems(credit['id']);
                                              final db = await _dbHelper.database;
                                              final custData = await db.query('customers', where: 'id = ?', whereArgs: [credit['id']]);
                                              
                                              if (custData.isNotEmpty) {
                                                setModalState(() {
                                                  items = newItems;
                                                  credit['debt'] = custData.first['debt'];
                                                });
                                                _refreshCredits(); 
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        // زر إرجاع السلعة (سلة المهملات)
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _returnItemToStockDialog(item, credit, lang, () async {
                                              final newItems = await _dbHelper.getCustomerItems(credit['id']);
                                              final db = await _dbHelper.database;
                                              final custData = await db.query('customers', where: 'id = ?', whereArgs: [credit['id']]);
                                              
                                              if (custData.isNotEmpty) {
                                                setModalState(() {
                                                  items = newItems;
                                                  credit['debt'] = custData.first['debt'];
                                                });
                                                _refreshCredits(); 
                                              }
                                            });
                                          },
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStockSelectionModal(BuildContext context, Map<String, dynamic> credit, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) {
        return _AddCreditItemSheet(
          customer: credit,
          lang: lang,
          onItemAdded: () {
            _refreshCredits(); 
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _openCustomerFile(credit, lang);
            });
          },
        );
      },
    );
  }

  void _showPaymentDialog(Map<String, dynamic> credit, String lang) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    double maxDebt = (credit['debt'] as num?)?.toDouble() ?? 0.0;

    String title = 'Collect Credit Payment';
    String hint = 'Amount Paid (DA)';
    String valReq = 'Required';
    String valMax = 'Cannot exceed total balance';
    String btnCancel = 'Cancel';
    String btnPay = 'Register Payment';

    if (lang == 'ar') {
      title = 'تسجيل دفعة مالية من الحساب';
      hint = 'المبلغ المدفوع (DA)';
      valReq = 'مطلوب';
      valMax = 'المبلغ يتعدى رصيد الدين المتبقي!';
      btnCancel = 'إلغاء';
      btnPay = 'تسديد الدفعة';
    } else if (lang == 'fr') {
      title = 'Enregistrer un paiement';
      hint = 'Montant payé (DA)';
      valReq = 'Obligatoire';
      valMax = 'Le montant dépasse le solde restant';
      btnCancel = 'Annuler';
      btnPay = 'Valider le paiement';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: hint, suffixText: 'DA'),
            validator: (v) {
              if (v == null || v.isEmpty) return valReq;
              final amt = double.tryParse(v);
              if (amt == null || amt <= 0) return valReq;
              if (amt > maxDebt) return valMax;
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double payAmt = double.parse(amountController.text.trim());
                await _dbHelper.payDebt(credit['id'], payAmt);
                
                final db = await _dbHelper.database;
                await db.insert('customer_items', {
                  'customer_id': credit['id'],
                  'product_name': lang == 'ar' ? 'دفعة مالية (Paiement)' : 'Versement (Paiement)',
                  'quantity': 1,
                  'price': -payAmt,
                  'date': DateTime.now().toString().split(' ')[0]
                });

                if (context.mounted) Navigator.pop(context);
                _refreshCredits();
              }
            },
            child: Text(btnPay),
          )
        ],
      ),
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'دفتر الديون المستحقة والكريديت للزبائن',
        'sub': 'إجمالي مستحقاتك الخارجية طرف الزبائن:',
        'search_hint': 'ابحث باسم الزبون أو رقم الهاتف المربوط...',
        'btn_new': 'فتح حساب عميل جديد',
        'col_name': 'الزبون / الشركة المَدينة',
        'col_phone': 'رقم الهاتف',
        'col_debt': 'مجموع الدين المتبقي',
        'col_actions': 'إجراءات سريعة',
        'empty': 'دفتر الديون فارغ تماماً حالياً.',
      },
      'en': {
        'title': 'Customer Credit & Outstanding Debts Ledger',
        'sub': 'Total Outward Credit / Portfolio Receivables:',
        'search_hint': 'Search debtor by name or phone identifier...',
        'btn_new': 'Open New Customer File',
        'col_name': 'Client / Debtor Name',
        'col_phone': 'Phone No.',
        'col_debt': 'Outstanding Balance',
        'col_actions': 'Quick Management',
        'empty': 'No outstanding debt accounts found.',
      },
      'fr': {
        'title': 'Grand livre des crédits et dettes clients',
        'sub': 'Total des créances clients à recouvrer :',
        'search_hint': 'Rechercher un client par nom ou téléphone...',
        'btn_new': 'Nouveau dossier client',
        'col_name': 'Nom du Client / Débiteur',
        'col_phone': 'Téléphone',
        'col_debt': 'Solde restant dû',
        'col_actions': 'Actions Rapides',
        'empty': 'Aucun compte client créditeur trouvé.',
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getTxt('title', currentLang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${_getTxt('sub', currentLang)} ${_totalOutDebt.toStringAsFixed(2)} $currency',
                        style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateDebtorDialog(context, currentLang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0087B7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(_getTxt('btn_new', currentLang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2A3A) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterCredits,
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: _getTxt('search_hint', currentLang),
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
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
                    : _filteredCredits.isEmpty
                        ? Center(child: Text(_getTxt('empty', currentLang), style: const TextStyle(color: Colors.grey)))
                        : SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
                              columns: [
                                DataColumn(label: Text(_getTxt('col_name', currentLang))),
                                DataColumn(label: Text(_getTxt('col_phone', currentLang))),
                                DataColumn(label: Text(_getTxt('col_debt', currentLang))),
                                DataColumn(label: Text(_getTxt('col_actions', currentLang))),
                              ],
                              rows: _filteredCredits.map((credit) {
                                double debtVal = (credit['debt'] as num?)?.toDouble() ?? 0.0;
                                return DataRow(cells: [
                                  DataCell(Text(credit['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(credit['phone'] == null || credit['phone'].toString().isEmpty ? '-' : credit['phone'].toString())),
                                  DataCell(Text('${debtVal.toStringAsFixed(2)} $currency',
                                      style: TextStyle(color: debtVal > 0 ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.folder_open, color: Color(0xFF0087B7), size: 18),
                                          onPressed: () => _openCustomerFile(credit, currentLang),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.payments_outlined, color: Colors.green, size: 18),
                                          onPressed: debtVal <= 0 ? null : () => _showPaymentDialog(credit, currentLang),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () => _deleteCustomer(credit, currentLang),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// ويدجت إضافة القطع من المخزن لملف الزبون
// ==============================================================================
class _AddCreditItemSheet extends StatefulWidget {
  final Map<String, dynamic> customer;
  final String lang;
  final VoidCallback onItemAdded;

  const _AddCreditItemSheet({
    required this.customer,
    required this.lang,
    required this.onItemAdded,
  });

  @override
  State<_AddCreditItemSheet> createState() => _AddCreditItemSheetState();
}

class _AddCreditItemSheetState extends State<_AddCreditItemSheet> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allParts = [];
  List<Map<String, dynamic>> _searchResult = [];
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  DateTime? _lastKeyPressTime;
  Timer? _debounceStock;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _debounceStock?.cancel();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    final data = await _dbHelper.getProducts();
    if (!mounted) return;
    setState(() {
      _allParts = data;
      _searchResult = data;
    });
  }

  void _searchParts(String query) {
    if (_debounceStock?.isActive ?? false) _debounceStock!.cancel();
    _debounceStock = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        if (query.trim().isEmpty) {
          _searchResult = _allParts;
        } else {
          final q = query.toLowerCase();
          _searchResult = _allParts.where((part) {
            final ref = (part['reference'] ?? '').toString().toLowerCase();
            final name = (part['name'] ?? '').toString().toLowerCase();
            return ref.contains(q) || name.contains(q);
          }).toList();
        }
      });
    });
  }

  void _handleScannedBarcode(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final matchedPart = _allParts.firstWhere(
      (part) => part['reference'].toString().toLowerCase() == cleanBarcode.toLowerCase(),
      orElse: () => {},
    );

    if (matchedPart.isNotEmpty) {
      _promptQuantityAndPrice(matchedPart);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not found: $cleanBarcode'), backgroundColor: Colors.red),
      );
    }
  }

  void _promptQuantityAndPrice(Map<String, dynamic> part) {
    int maxStock = part['quantity'] ?? 0;
    if (maxStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.lang == 'ar' ? 'القطعة غير متوفرة في المخزن!' : 'Out of stock!'), backgroundColor: Colors.red),
      );
      return;
    }

    int selectedQty = 1;
    final priceController = TextEditingController(text: (part['selling_price'] ?? 0.0).toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(widget.lang == 'ar' ? 'تحديد الكمية والسعر' : 'Set Quantity & Price'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(part['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${widget.lang == 'ar' ? 'المخزون المتاح:' : 'Available Stock:'} $maxStock', style: const TextStyle(color: Colors.grey)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: selectedQty > 1 ? () => setDialogState(() => selectedQty--) : null,
                      ),
                      Text('$selectedQty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: selectedQty < maxStock ? () => setDialogState(() => selectedQty++) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: widget.lang == 'ar' ? 'سعر البيع المفرّد (كريديت)' : 'Unit Price (Credit)',
                      suffixText: 'DA',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.lang == 'ar' ? 'إلغاء' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
                  onPressed: () async {
                    double finalPrice = double.tryParse(priceController.text) ?? (part['selling_price'] as num).toDouble();
                    
                    Map<String, dynamic> productToCredit = Map.from(part);
                    productToCredit['selling_price'] = finalPrice;

                    Navigator.pop(context); 

                    await _dbHelper.addCreditToCustomer(widget.customer['id'], productToCredit, selectedQty);
                    
                    Navigator.pop(context); 
                    widget.onItemAdded(); 
                  },
                  child: Text(widget.lang == 'ar' ? 'تأكيد الإضافة' : 'Confirm Addition'),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);

    return KeyboardListener(
      focusNode: _focusNode,
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
              _handleScannedBarcode(_barcodeBuffer);
              _barcodeBuffer = '';
            }
          } else if (character != null) {
            _barcodeBuffer += character;
          }
        }
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.lang == 'ar' ? 'اختر قطعة من المخزن لـ ${widget.customer['name']}' : 'Select Part for ${widget.customer['name']}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _searchParts,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.lang == 'ar' ? 'ابحث بالاسم, الرمز أو امسح الباركود...' : 'Search or Scan barcode...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _searchResult.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final part = _searchResult[index];
                  int stock = part['quantity'] ?? 0;
                  return ListTile(
                    title: Text(part['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${part['reference']} • Stock: $stock'),
                    trailing: Text('${part['selling_price']} DA', style: const TextStyle(color: Color(0xFF0087B7), fontWeight: FontWeight.bold)),
                    onTap: () => _promptQuantityAndPrice(part),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}