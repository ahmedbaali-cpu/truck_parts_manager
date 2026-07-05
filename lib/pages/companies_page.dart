import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:truck_parts_manager/database/db_helper.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final DbHelper _dbHelper = DbHelper();
  List<Map<String, dynamic>> _allCompanies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _isLoading = true;

  double _totalCompanyDebt = 0.0;
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    _refreshCompanies();
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCompanies() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = await _dbHelper.getAllCompanies();
    if (!mounted) return;
    setState(() {
      _allCompanies = data;
      _filteredCompanies = data;
      _calculateTotalCompanyDebt();
      _isLoading = false;
    });
  }

  void _calculateTotalCompanyDebt() {
    _totalCompanyDebt = 0.0;
    for (var company in _allCompanies) {
      _totalCompanyDebt += (company['company_debt'] as num?)?.toDouble() ?? 0.0;
    }
  }

  void _filterCompanies(String query) {
    if (_debounceSearch?.isActive ?? false) _debounceSearch!.cancel();
    _debounceSearch = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filteredCompanies = _allCompanies.where((company) {
          final name = (company['company_name'] ?? '').toString().toLowerCase();
          final contact = (company['company_contact'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase()) || contact.contains(query.toLowerCase());
        }).toList();
      });
    });
  }

  // ========================================================
  // إنشاء أو تعديل ملف شركة
  // ========================================================
  void _showCompanyDialog(BuildContext context, String lang, {Map<String, dynamic>? companyToEdit}) {
    final isEditing = companyToEdit != null;
    final nameController = TextEditingController(text: isEditing ? companyToEdit['company_name'] : '');
    final contactController = TextEditingController(text: isEditing ? companyToEdit['company_contact'] : '');
    final formKey = GlobalKey<FormState>();

    String title = isEditing ? 'Edit Supplier' : 'Register New Supplier';
    String labelName = 'Company Name';
    String labelContact = 'Contact Person / Phone';
    String valReq = 'Required';
    String btnCancel = 'Cancel';
    String btnSave = isEditing ? 'Save Changes' : 'Create';

    if (lang == 'ar') {
      title = isEditing ? 'تعديل بيانات المورد' : 'تسجيل شركة توريد جديدة';
      labelName = 'اسم الشركة / المورد الرئيسي';
      labelContact = 'مسؤول الاتصال / رقم الهاتف';
      valReq = 'مطلوب';
      btnCancel = 'إلغاء';
      btnSave = isEditing ? 'حفظ التعديلات' : 'إنشاء ملف';
    } else if (lang == 'fr') {
      title = isEditing ? 'Modifier le fournisseur' : 'Enregistrer un fournisseur';
      labelName = 'Nom de la société';
      labelContact = 'Contact / Téléphone';
      valReq = 'Obligatoire';
      btnCancel = 'Annuler';
      btnSave = isEditing ? 'Enregistrer' : 'Créer';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                controller: contactController,
                decoration: InputDecoration(labelText: labelContact),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = await _dbHelper.database;
                if (isEditing) {
                  await db.rawUpdate('UPDATE companies SET company_name = ?, company_contact = ? WHERE id = ?', 
                    [nameController.text.trim(), contactController.text.trim(), companyToEdit['id']]);
                } else {
                  await _dbHelper.createNewCompany(nameController.text.trim(), contactController.text.trim());
                }
                if (context.mounted) Navigator.pop(context);
                _refreshCompanies();
              }
            },
            child: Text(btnSave),
          )
        ],
      ),
    );
  }

  // ========================================================
  // حذف المورد
  // ========================================================
  Future<void> _deleteCompanyDialog(Map<String, dynamic> company, String lang) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(lang == 'ar' ? 'حذف المورد؟' : 'Delete Supplier?', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(lang == 'ar' 
          ? 'هل أنت متأكد من حذف المورد (${company['company_name']}) نهائياً؟ سيتم مسح كل فواتيره من السجل ولن تتأثر السلع في المخزن.'
          : 'Are you sure you want to delete (${company['company_name']})? All history will be erased.'),
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
      // تصحيح اسم الجدول حسب قاعدة البيانات
      await db.rawDelete('DELETE FROM company_invoices WHERE company_id = ?', [company['id']]);
      await db.rawDelete('DELETE FROM companies WHERE id = ?', [company['id']]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'ar' ? 'تم الحذف بنجاح' : 'Deleted successfully'),
          backgroundColor: Colors.green,
        ));
      }
      _refreshCompanies();
    }
  }

  // ========================================================
  // تسجيل دفعة للمورد (Versement)
  // ========================================================
  void _showPaymentToSupplierDialog(Map<String, dynamic> company, String lang) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    double maxDebt = (company['company_debt'] as num?)?.toDouble() ?? 0.0;

    String title = 'Pay Supplier';
    String hint = 'Amount Paid (DA)';
    String valReq = 'Required';
    String valMax = 'Cannot exceed total balance';
    String btnCancel = 'Cancel';
    String btnPay = 'Register Payment';

    if (lang == 'ar') {
      title = 'تسجيل دفعة للمورد';
      hint = 'المبلغ المدفوع (DA)';
      valReq = 'مطلوب';
      valMax = 'المبلغ يتعدى ديونك لدى المورد!';
      btnCancel = 'إلغاء';
      btnPay = 'تسديد الدفعة';
    } else if (lang == 'fr') {
      title = 'Payer le fournisseur';
      hint = 'Montant payé (DA)';
      valReq = 'Obligatoire';
      valMax = 'Le montant dépasse la dette';
      btnCancel = 'Annuler';
      btnPay = 'Valider le paiement';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel, style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double payAmt = double.parse(amountController.text.trim());
                
                final db = await _dbHelper.database;
                await db.rawUpdate('UPDATE companies SET company_debt = company_debt - ? WHERE id = ?', [payAmt, company['id']]);
                
                // تصحيح الأعمدة واسم الجدول
                await db.insert('company_invoices', {
                  'company_id': company['id'],
                  'name': lang == 'ar' ? 'دفعة مالية (Paiement)' : 'Versement (Paiement)',
                  'reference': 'PAYMENT',
                  'quantity_bought': 1,
                  'cost_charged': -payAmt, 
                  'date_added': DateTime.now().toString().split(' ')[0]
                });

                if (context.mounted) Navigator.pop(context);
                _refreshCompanies();
              }
            },
            child: Text(btnPay),
          )
        ],
      ),
    );
  }

  // ========================================================
  // تعديل سعر الوحدة لسلعة في الفاتورة
  // ========================================================
  void _editSupplierItemCostDialog(Map<String, dynamic> item, Map<String, dynamic> company, String lang, VoidCallback onSaved) {
    // استخدام cost_charged من قاعدة البيانات
    final costController = TextEditingController(text: item['cost_charged'].toString());
    final formKey = GlobalKey<FormState>();

    String title = 'Edit Wholesale Unit Price';
    String hint = 'New Unit Price (DA)';
    String btnCancel = 'Cancel';
    String btnSave = 'Save';

    if (lang == 'ar') {
      title = 'تعديل سعر شراء الوحدة';
      hint = 'سعر الوحدة الجديد (DA)';
      btnCancel = 'إلغاء';
      btnSave = 'حفظ التعديل';
    } else if (lang == 'fr') {
      title = 'Modifier le prix d\'achat unitaire';
      hint = 'Nouveau prix unitaire (DA)';
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
            controller: costController,
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
                double newUnitCost = double.parse(costController.text.trim());
                double oldUnitCost = (item['cost_charged'] as num).toDouble();
                int qty = (item['quantity_bought'] as num).toInt();
                
                double diffTotal = (newUnitCost * qty) - (oldUnitCost * qty);

                final db = await _dbHelper.database;
                // تصحيح الأعمدة واسم الجدول
                await db.rawUpdate('UPDATE company_invoices SET cost_charged = ? WHERE id = ?', [newUnitCost, item['id']]);
                await db.rawUpdate('UPDATE companies SET company_debt = company_debt + ? WHERE id = ?', [diffTotal, company['id']]);

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
  // إرجاع سلعة للمورد (حذف وإنقاص الكمية من المخزن)
  // ========================================================
  void _returnItemToSupplierDialog(Map<String, dynamic> item, Map<String, dynamic> company, String lang, VoidCallback onDeleted) {
    String title = 'Return Item to Supplier?';
    String content = 'This item will be deleted from the bill, the debt will be reduced, and the quantity will be removed from your stock inventory.';
    String btnCancel = 'Cancel';
    String btnConfirm = 'Confirm Return';

    if (lang == 'ar') {
      title = 'إرجاع القطعة للمورد؟';
      content = 'سيتم حذف هذه القطعة من فاتورة المورد، إنقاص الديون المستحقة عليك، و سيتم سحب الكمية من المخزن لأنك قمت بإرجاعها.';
      btnCancel = 'إلغاء';
      btnConfirm = 'تأكيد الإرجاع';
    } else if (lang == 'fr') {
      title = 'Retourner au fournisseur?';
      content = 'Cet article sera supprimé de la facture, la dette sera réduite et la quantité sera retirée de votre stock.';
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
              
              double unitCost = (item['cost_charged'] as num).toDouble();
              int qty = (item['quantity_bought'] as num).toInt();
              double totalCost = unitCost * qty;

              await db.rawUpdate('UPDATE companies SET company_debt = company_debt - ? WHERE id = ?', [totalCost, company['id']]);
              await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE reference = ?', [qty, item['reference']]);
              // تصحيح اسم الجدول
              await db.rawDelete('DELETE FROM company_invoices WHERE id = ?', [item['id']]);

              if (context.mounted) Navigator.pop(context);
              onDeleted(); 
            },
            child: Text(btnConfirm),
          )
        ],
      ),
    );
  }

  // ========================================================
  // توليد كشف الحساب بـ PDF
  // ========================================================
  Future<Uint8List> _generateSupplierPdfBytes(Map<String, dynamic> company, List<Map<String, dynamic>> items, PdfPageFormat format) async {
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

    final String statementNumber = 'SUP-${company['id']}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    double totalDebt = (company['company_debt'] as num?)?.toDouble() ?? 0.0;

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
                      child: pw.Text('TOTAL RESTE A PAYER: ${totalDebt.toStringAsFixed(2)} DA', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    )
                  ]
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Signature Fournisseur:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
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
                    pw.Text('Gestion des fournisseurs', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                  ]
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey400)
                  ),
                  child: pw.Text('RELEVE DE COMPTE', style: pw.TextStyle(font: fontBold, fontSize: 14)), 
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
                    pw.Text('Fournisseur: ${company['company_name']}', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                    if (company['company_contact'] != null && company['company_contact'].toString().isNotEmpty)
                      pw.Text('Contact: ${company['company_contact']}', style: pw.TextStyle(font: font, fontSize: 12)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Ref: $statementNumber', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}', style: pw.TextStyle(font: font, fontSize: 12)),
                  ]
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Designation', 'Qte', 'Prix U (DA)', 'Total (DA)'],
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
                // تصحيح الأعمدة لتتوافق مع قاعدة البيانات
                String rawDate = item['date_added']?.toString() ?? '';
                String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
                double cost = (item['cost_charged'] as num).toDouble();
                int qty = (item['quantity_bought'] as num).toInt();
                double total = cost * qty;
                bool isPayment = cost < 0; 
                
                return [
                  formattedDate,
                  item['name'] ?? '',
                  isPayment ? '-' : '$qty', 
                  isPayment ? '-' : cost.toStringAsFixed(2),
                  total.toStringAsFixed(2) 
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  void _showInAppPreview(Map<String, dynamic> company, List<Map<String, dynamic>> items, String lang) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang == 'ar' ? 'معاينة كشف الحساب' : 'Supplier Ledger Preview',
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
              build: (format) => _generateSupplierPdfBytes(company, items, format),
              allowPrinting: true, 
              allowSharing: true,  
              canChangeOrientation: true, 
              canChangePageFormat: true,  
              canDebug: false, 
              pdfFileName: 'Releve_${company['company_name']}.pdf',
            ),
          ),
        );
      },
    );
  }

  // ========================================================
  // فتح ملف المورد
  // ========================================================
  void _openCompanyFile(Map<String, dynamic> initialCompany, String lang) async {
    List<Map<String, dynamic>> items = await _dbHelper.getCompanyItems(initialCompany['id']);
    Map<String, dynamic> company = Map.from(initialCompany);

    if (!mounted) return;

    String currentDebtText = 'Total Due to Supplier:';
    String addPurchasesText = 'Record Supplier Invoice';
    String printBillText = 'Print Ledger';
    String partsBoughtText = 'Invoices and Payments History:';
    String noPartsText = 'No entries registered under this supplier.';

    if (lang == 'ar') {
      currentDebtText = 'إجمالي ديون المورد:';
      addPurchasesText = 'تسجيل فاتورة شحن جديدة';
      printBillText = 'طباعة كشف حساب';
      partsBoughtText = 'سجل فواتير الشراء والدفعات:';
      noPartsText = 'لم يتم تسجيل أي فواتير أو دفعات من هذا المورد بعد.';
    } else if (lang == 'fr') {
      currentDebtText = 'Total dû au fournisseur :';
      addPurchasesText = 'Enregistrer facture';
      printBillText = 'Imprimer le relevé';
      partsBoughtText = 'Historique des factures et versements :';
      noPartsText = 'Aucun enregistrement pour ce fournisseur.';
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
                            Text(company['company_name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('$currentDebtText ${company['company_debt']} DA', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
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
                              _showInAppPreview(company, items, lang);
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            icon: const Icon(Icons.playlist_add_circle_outlined, size: 18),
                            label: Text(addPurchasesText),
                            onPressed: () => _showAddItemToCompanyDialog(context, company, lang, () async {
                              final newItems = await _dbHelper.getCompanyItems(company['id']);
                              final db = await _dbHelper.database;
                              final compData = await db.query('companies', where: 'id = ?', whereArgs: [company['id']]);
                              if (context.mounted) {
                                setModalState(() {
                                  items = newItems;
                                  company['company_debt'] = compData.first['company_debt']; 
                                });
                                _refreshCompanies();
                              }
                            }),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(height: 32),
                  Text(partsBoughtText, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Text(noPartsText))
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              // تصحيح الأعمدة لتتوافق مع company_invoices
                              double unitCost = (item['cost_charged'] ?? 0).toDouble();
                              int qty = (item['quantity_bought'] ?? 1).toInt();
                              double totalBatchCost = unitCost * qty;
                              bool isPayment = unitCost < 0;

                              String rawDate = item['date_added']?.toString() ?? '';
                              String formattedDate = rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(
                                    isPayment ? Icons.payments : Icons.local_shipping,
                                    color: isPayment ? Colors.green : Colors.orange,
                                  ),
                                  title: Text(
                                    isPayment ? (item['name'] ?? '') : '${item['name'] ?? ''} (x$qty)',
                                    style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                  subtitle: Text(isPayment ? 'Date: $formattedDate' : 'Ref: ${item['reference']} | Date: $formattedDate'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${totalBatchCost.toStringAsFixed(2)} DA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          color: isPayment ? Colors.green : Colors.redAccent
                                        )
                                      ),
                                      if (!isPayment) ...[
                                        const SizedBox(width: 8),
                                        // تعديل سعر السلعة
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _editSupplierItemCostDialog(item, company, lang, () async {
                                              final newItems = await _dbHelper.getCompanyItems(company['id']);
                                              final db = await _dbHelper.database;
                                              final compData = await db.query('companies', where: 'id = ?', whereArgs: [company['id']]);
                                              if (compData.isNotEmpty) {
                                                setModalState(() {
                                                  items = newItems;
                                                  company['company_debt'] = compData.first['company_debt'];
                                                });
                                                _refreshCompanies();
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 4),
                                        // إرجاع السلعة للمورد وحذفها من المخزن
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            _returnItemToSupplierDialog(item, company, lang, () async {
                                              final newItems = await _dbHelper.getCompanyItems(company['id']);
                                              final db = await _dbHelper.database;
                                              final compData = await db.query('companies', where: 'id = ?', whereArgs: [company['id']]);
                                              if (compData.isNotEmpty) {
                                                setModalState(() {
                                                  items = newItems;
                                                  company['company_debt'] = compData.first['company_debt'];
                                                });
                                                _refreshCompanies();
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

  // ========================================================
  // نافذة تسجيل شحنة/سلعة من مورد (ترفع المخزون والمديونية)
  // ========================================================
  void _showAddItemToCompanyDialog(BuildContext context, Map<String, dynamic> company, String lang, VoidCallback onSuccess) {
    final refController = TextEditingController();
    final nameController = TextEditingController();
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String title = 'Record Invoice Entry';
    String labelRef = 'Part Reference';
    String labelName = 'Part Name';
    String labelQty = 'Quantity Bought';
    String labelCost = 'Wholesale Unit Price';
    String valReq = 'Required';
    String btnCancel = 'Cancel';
    String btnAdd = 'Add to Ledger';

    if (lang == 'ar') {
      title = 'تسجيل سلعة / فاتورة شحن';
      labelRef = 'مرجع القطعة (Reference)';
      labelName = 'اسم القطعة';
      labelQty = 'الكمية المستوردة';
      labelCost = 'سعر شراء الوحدة (الجملة)';
      valReq = 'مطلوب';
      btnCancel = 'إلغاء';
      btnAdd = 'تسجيل السلعة';
    } else if (lang == 'fr') {
      title = 'Enregistrer une facture';
      labelRef = 'Référence';
      labelName = 'Nom de la pièce';
      labelQty = 'Quantité achetée';
      labelCost = 'Prix de revient unitaire';
      valReq = 'Obligatoire';
      btnCancel = 'Annuler';
      btnAdd = 'Ajouter';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: refController, decoration: InputDecoration(labelText: labelRef), validator: (v) => v!.isEmpty ? valReq : null),
              TextFormField(controller: nameController, decoration: InputDecoration(labelText: labelName), validator: (v) => v!.isEmpty ? valReq : null),
              TextFormField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: labelQty), validator: (v) => v!.isEmpty ? valReq : null),
              TextFormField(controller: costController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: labelCost), validator: (v) => v!.isEmpty ? valReq : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(btnCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0087B7), foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                double unitCost = double.parse(costController.text.trim());
                int qty = int.parse(qtyController.text.trim());
                double totalCost = unitCost * qty;
                String ref = refController.text.trim();
                String name = nameController.text.trim();

                final db = await _dbHelper.database;
                
                // 1. تصحيح اسم الجدول والأعمدة ليتطابق مع db_helper
                await db.insert('company_invoices', {
                  'company_id': company['id'],
                  'name': name,
                  'reference': ref,
                  'quantity_bought': qty,
                  'cost_charged': unitCost,
                  'date_added': DateTime.now().toString().split(' ')[0]
                });

                // 2. تحديث ديون المورد
                await db.rawUpdate('UPDATE companies SET company_debt = company_debt + ? WHERE id = ?', [totalCost, company['id']]);

                // 3. تحديث أو إضافة القطعة للمخزن (بدون استخدام عمود barcode غير الموجود في الـ db)
                var existing = await db.query('products', where: 'reference = ?', whereArgs: [ref]);
                if (existing.isNotEmpty) {
                  await db.rawUpdate('UPDATE products SET quantity = quantity + ?, buying_price = ? WHERE reference = ?', [qty, unitCost, ref]);
                } else {
                  await db.insert('products', {
                    'name': name,
                    'reference': ref,
                    'quantity': qty,
                    'buying_price': unitCost,
                    'selling_price': unitCost * 1.3, // 30% هامش ربح افتراضي
                  });
                }

                onSuccess();
              }
            },
            child: Text(btnAdd),
          )
        ],
      ),
    );
  }

  String _getTxt(String key, String lang) {
    final Map<String, Map<String, String>> tx = {
      'ar': {
        'title': 'سجل الموردين والشركات',
        'sub': 'إجمالي الديون المستحقة للموردين:',
        'search_hint': 'ابحث باسم الشركة أو مسؤول الاتصال...',
        'btn_new': 'تسجيل مورد جديد',
        'col_name': 'اسم الشركة / المورد',
        'col_contact': 'مسؤول الاتصال',
        'col_debt': 'الديون المستحقة عليك',
        'col_actions': 'إجراءات سريعة',
        'empty': 'سجل الموردين فارغ تماماً حالياً.',
      },
      'en': {
        'title': 'Suppliers & Companies Ledger',
        'sub': 'Total Payable Debt to Suppliers:',
        'search_hint': 'Search by company name or contact...',
        'btn_new': 'Register New Supplier',
        'col_name': 'Company / Supplier',
        'col_contact': 'Contact Person',
        'col_debt': 'Total Due',
        'col_actions': 'Actions',
        'empty': 'No suppliers found.',
      },
      'fr': {
        'title': 'Registre des Fournisseurs',
        'sub': 'Total des dettes fournisseurs :',
        'search_hint': 'Rechercher par nom ou contact...',
        'btn_new': 'Nouveau Fournisseur',
        'col_name': 'Société / Fournisseur',
        'col_contact': 'Contact',
        'col_debt': 'Reste à payer',
        'col_actions': 'Actions Rapides',
        'empty': 'Aucun fournisseur trouvé.',
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
                    Text('${_getTxt('sub', currentLang)} ${_totalCompanyDebt.toStringAsFixed(2)} $currency',
                        style: const TextStyle(fontSize: 14, color: Colors.orangeAccent, fontWeight: FontWeight.w500)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCompanyDialog(context, currentLang),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0087B7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  icon: const Icon(Icons.domain_add, size: 18),
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
                      onChanged: _filterCompanies,
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
                    : _filteredCompanies.isEmpty
                        ? Center(child: Text(_getTxt('empty', currentLang), style: const TextStyle(color: Colors.grey)))
                        : SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey[50]),
                              columns: [
                                DataColumn(label: Text(_getTxt('col_name', currentLang))),
                                DataColumn(label: Text(_getTxt('col_contact', currentLang))),
                                DataColumn(label: Text(_getTxt('col_debt', currentLang))),
                                DataColumn(label: Text(_getTxt('col_actions', currentLang))),
                              ],
                              rows: _filteredCompanies.map((company) {
                                double debtVal = (company['company_debt'] as num?)?.toDouble() ?? 0.0;
                                return DataRow(cells: [
                                  DataCell(Text(company['company_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(company['company_contact'] == null || company['company_contact'].toString().isEmpty ? '-' : company['company_contact'].toString())),
                                  DataCell(Text('${debtVal.toStringAsFixed(2)} $currency',
                                      style: TextStyle(color: debtVal > 0 ? Colors.orangeAccent : Colors.green, fontWeight: FontWeight.bold))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // فتح الفواتير وكشف الحساب
                                        IconButton(
                                          icon: const Icon(Icons.folder_open, color: Color(0xFF0087B7), size: 18),
                                          onPressed: () => _openCompanyFile(company, currentLang),
                                        ),
                                        // دفع للمورد
                                        IconButton(
                                          icon: const Icon(Icons.payments_outlined, color: Colors.green, size: 18),
                                          onPressed: debtVal <= 0 ? null : () => _showPaymentToSupplierDialog(company, currentLang),
                                        ),
                                        // تعديل بيانات المورد
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueGrey, size: 18),
                                          onPressed: () => _showCompanyDialog(context, currentLang, companyToEdit: company),
                                        ),
                                        // حذف المورد نهائياً
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          onPressed: () => _deleteCompanyDialog(company, currentLang),
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