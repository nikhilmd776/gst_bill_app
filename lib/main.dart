import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

late SharedPreferences prefs;
List<Map<String, dynamic>> savedProducts = [];
Map<String, String> customerPhoneMap = {};
int invoiceNo = 1;

// GLOBAL NOTIFIERS
final companyNotifier = ValueNotifier<String>('Your Shop Name');
final gstinNotifier = ValueNotifier<String>('27AAAAA0000A1Z5');
final addressNotifier = ValueNotifier<String>('Your Shop Address');
final logoNotifier = ValueNotifier<Uint8List?>(null);

// Live total
final ValueNotifier<double> totalNotifier = ValueNotifier(0.0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  _loadGlobalData();
  runApp(const MyApp());
}

void _loadGlobalData() {
  companyNotifier.value = prefs.getString('companyName') ?? 'Your Shop Name';
  gstinNotifier.value = prefs.getString('gstin') ?? '27AAAAA0000A1Z5';
  addressNotifier.value = prefs.getString('address') ?? 'Your Shop Address';
  invoiceNo = (prefs.getInt('invoiceNo') ?? 0) + 1;

  final base64 = prefs.getString('logoBase64');
  if (base64 != null) {
    try {
      final bytes = base64Decode(base64);
      logoNotifier.value = bytes;
    } catch (e) {
      logoNotifier.value = null;
    }
  } else {
    logoNotifier.value = null;
  }

  final productsJson = prefs.getString('savedProducts');
  if (productsJson != null) {
    savedProducts = List<Map<String, dynamic>>.from(jsonDecode(productsJson));
  }

  final phoneJson = prefs.getString('customerPhones');
  if (phoneJson != null) {
    customerPhoneMap = Map<String, String>.from(jsonDecode(phoneJson));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invoice Generator',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const BillScreen(),
    );
  }
}

class Product {
  String name = '';
  String details = '';
  int qty = 1;
  double rate = 0.0;
  double gstPercent = 18.0;

  final rateController = TextEditingController();
  final hsnController = TextEditingController();
  final gstController = TextEditingController();

  double get total => qty * rate * (1 + gstPercent / 100);
  double get taxable => qty * rate;
  double get gst => qty * rate * (gstPercent / 100);
}

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});
  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _formKey = GlobalKey<FormState>();
  String customerName = '';
  String customerPhone = '';
  String customerAddress = '';
  String invoiceType = 'estimate';
  final List<Product> products = [Product()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTotal());
  }

  @override
  void dispose() {
    for (final p in products) {
      p.rateController.dispose();
      p.hsnController.dispose();
      p.gstController.dispose();
    }
    super.dispose();
  }

  void _updateTotal() {
    final total = products.fold(0.0, (sum, p) => sum + p.total);
    totalNotifier.value = total;
  }

  void addProduct() {
    setState(() => products.add(Product()));
    _updateTotal();
  }

  void removeProduct(int index) {
    final p = products[index];
    p.rateController.dispose();
    p.hsnController.dispose();
    p.gstController.dispose();
    setState(() => products.removeAt(index));
    _updateTotal();
  }

  String numberToWords(int number) {
    if (number == 0) return 'Zero';
    const List<String> ones = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const List<String> tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];
    String word = '';
    if (number >= 10000000) {
      word += '${numberToWords(number ~/ 10000000)} Crore ';
      number %= 10000000;
    }
    if (number >= 100000) {
      word += '${numberToWords(number ~/ 100000)} Lakh ';
      number %= 100000;
    }
    if (number >= 1000) {
      word += '${numberToWords(number ~/ 1000)} Thousand ';
      number %= 1000;
    }
    if (number >= 100) {
      word += '${ones[number ~/ 100]} Hundred ';
      number %= 100;
    }
    if (number > 0) {
      if (number < 20) {
        word += ones[number];
      } else {
        word += tens[number ~/ 10];
        if (number % 10 > 0) word += ' ${ones[number % 10]}';
      }
    }
    return word.trim();
  }

  Future<void> generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    // Validate Product Names
    for (int i = 0; i < products.length; i++) {
      if (products[i].name.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product Name is required for item ${i + 1}'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop PDF generation
      }
    }
    final String pdfCustomerAddress = customerAddress;
    for (final p in products) {
      p.rate = double.tryParse(p.rateController.text) ?? 0;
      p.gstPercent = double.tryParse(p.gstController.text) ?? 18;
      p.details = p.hsnController.text;
    }
    _updateTotal();

    if (customerName.isNotEmpty && customerPhone.isNotEmpty) {
      customerPhoneMap[customerName] = customerPhone;
      await prefs.setString('customerPhones', jsonEncode(customerPhoneMap));
    }

    await prefs.setInt('invoiceNo', invoiceNo);

    final pdf = pw.Document();
    final date = DateFormat('dd MMM yyyy').format(DateTime.now());
    final font = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();

    final logo = logoNotifier.value != null ? pw.MemoryImage(logoNotifier.value!) : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                children: [
                  if (logo != null)
                    pw.Container(
                      width: 80,
                      height: 80,
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(8),
                        image: pw.DecorationImage(image: logo, fit: pw.BoxFit.cover),
                      ),
                    ),
                  if (logo != null) pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyNotifier.value, style: pw.TextStyle(font: bold, fontSize: 20)),
                        pw.Text(addressNotifier.value, style: pw.TextStyle(font: font, fontSize: 12)),
                        if (invoiceType != 'estimate')
                          pw.Text('GSTIN: ${gstinNotifier.value}', style: pw.TextStyle(font: font, fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.Column(
                    children: [
                        pw.Text(
                        invoiceType == 'estimate' ? 'ESTIMATE' : 'TAX INVOICE',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 18,
                          color: invoiceType == 'estimate' ? PdfColors.red800 : PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Invoice: #$invoiceNo', style: pw.TextStyle(font: font)),
                      pw.Text('Date: $date', style: pw.TextStyle(font: font)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('Bill To: ', style: pw.TextStyle(font: bold)),
                      pw.Text(customerName, style: pw.TextStyle(font: font)),
                    ],
                  ),
                  if (pdfCustomerAddress.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Text(pdfCustomerAddress, style: pw.TextStyle(font: font, fontSize: 10)),
                    ),
                  if (customerPhone.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        children: [
                          pw.Spacer(),
                          pw.Text('Phone: $customerPhone', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: ['#', 'Item', 'HSN', 'Qty', 'Rate', 'Taxable', 'CGST', 'SGST', 'Total']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(h, style: pw.TextStyle(font: bold)),
                          ))
                      .toList(),
                ),
                ...products.asMap().entries.map((e) {
                  final i = e.key + 1;
                  final p = e.value;
                  return pw.TableRow(
                    children: [
                      i.toString(),
                      p.name,
                      p.details,
                      p.qty.toString(),
                      p.rate.toStringAsFixed(2),
                      p.taxable.toStringAsFixed(2),
                      (p.gst / 2).toStringAsFixed(2),
                      (p.gst / 2).toStringAsFixed(2),
                      p.total.toStringAsFixed(2),
                    ].map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(cell, style: pw.TextStyle(font: font)),
                        )).toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 300,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: pw.TextStyle(font: font)),
                        pw.Text(products.fold(0.0, (s, p) => s + p.taxable).toStringAsFixed(2), style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('CGST:', style: pw.TextStyle(font: font)),
                        pw.Text((totalNotifier.value / 2 - products.fold(0.0, (s, p) => s + p.taxable)).toStringAsFixed(2), style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('SGST:', style: pw.TextStyle(font: font)),
                        pw.Text((totalNotifier.value / 2 - products.fold(0.0, (s, p) => s + p.taxable)).toStringAsFixed(2), style: pw.TextStyle(font: font)),
                      ],
                    ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Grand Total:', style: pw.TextStyle(font: bold, fontSize: 16)),
                        pw.Text(totalNotifier.value.toStringAsFixed(2), style: pw.TextStyle(font: bold, fontSize: 16)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('In Words: ${numberToWords(totalNotifier.value.round())} Only', style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text('Thank You! Visit Again', style: pw.TextStyle(font: bold, color: PdfColors.grey700)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invoice_$invoiceNo.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Invoice #$invoiceNo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Generator'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) {
                final json = prefs.getString('savedProducts');
                if (json != null) {
                  savedProducts = List<Map<String, dynamic>>.from(jsonDecode(json));
                }
                setState(() {}); // Rebuild UI
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // FLOATING RIBBON BANNER — CENTERED
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.indigo, Colors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: -12,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -12,
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ValueListenableBuilder<Uint8List?>(
                              valueListenable: logoNotifier,
                              builder: (context, logo, _) {
                                if (logo != null) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      logo,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }
                                return const SizedBox(width: 70);
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ValueListenableBuilder<String>(
                                    valueListenable: companyNotifier,
                                    builder: (context, name, _) {
                                      return Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  ValueListenableBuilder<String>(
                                    valueListenable: gstinNotifier,
                                    builder: (context, gst, _) {
                                      return Text(
                                        'GSTIN: $gst',
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        textAlign: TextAlign.center,
                                      );
                                    },
                                  ),
                                  ValueListenableBuilder<String>(
                                    valueListenable: addressNotifier,
                                    builder: (context, addr, _) {
                                      return Text(
                                        addr,
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ],
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
            const SizedBox(height: 16),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        customerName = v.trim();
                        if (customerPhoneMap.containsKey(v)) {
                          customerPhone = customerPhoneMap[v]!;
                          setState(() {});
                        }
                      },
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (v) => customerName = v!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      initialValue: customerPhone,
                      onChanged: (v) => customerPhone = v.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (v) => customerAddress = v.trim(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            const SizedBox(height: 16),
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
                        value: 'estimate',
                        groupValue: invoiceType,
                        onChanged: (val) => setState(() => invoiceType = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Tax Invoice'),
                        value: 'invoice',
                        groupValue: invoiceType,
                        onChanged: (val) => setState(() => invoiceType = val!),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Text('Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const SizedBox(height: 8),
            ...products.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              return Card(
                color: Colors.blue.shade50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                          return savedProducts
                              .where((prod) => prod['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()))
                              .map((prod) => prod['name'].toString());
                        },
                        onSelected: (selection) {
                          final selected = savedProducts.firstWhere(
                            (prod) => prod['name'].toString().trim().toLowerCase() == selection.trim().toLowerCase(),
                            orElse: () => <String, dynamic>{},
                          );
                          if (selected.isNotEmpty) {
                            p.name = selected['name'];
                            p.details = selected['hsn'] ?? '';
                            p.rate = double.tryParse(selected['rate'].toString()) ?? 0.0;
                            p.gstPercent = double.tryParse(selected['gst'].toString()) ?? 18.0;

                            p.hsnController.text = p.details;
                            p.rateController.text = p.rate > 0 ? p.rate.toStringAsFixed(2) : '';
                            p.gstController.text = p.gstPercent > 0 ? p.gstPercent.toString() : '';

                            _updateTotal();
                          }
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          controller.text = p.name;
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Product Name *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            onChanged: (v) => p.name = v,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: p.hsnController,
                        decoration: const InputDecoration(labelText: 'HSN / Details', border: OutlineInputBorder()),
                        onChanged: (v) => p.details = v,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              initialValue: p.qty.toString(),
                              onChanged: (v) {
                                p.qty = int.tryParse(v) ?? 1;
                                _updateTotal();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: p.rateController,
                              decoration: const InputDecoration(labelText: 'Rate', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                p.rate = double.tryParse(v) ?? 0;
                                _updateTotal();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: p.gstController,
                              decoration: const InputDecoration(labelText: 'GST%', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                p.gstPercent = double.tryParse(v) ?? 18;
                                _updateTotal();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: products.length > 1 ? () => removeProduct(i) : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: addProduct,
            ),
            const SizedBox(height: 20),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                tooltip: 'Clear All Products',
                onPressed: products.length > 1 || products[0].name.isNotEmpty
                    ? () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear All Products?'),
                            content: const Text('This will remove all product entries.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (final p in products) {
                                      p.name = '';
                                      p.details = '';
                                      p.qty = 1;
                                      p.rate = 0.0;
                                      p.gstPercent = 18.0;
                                      p.rateController.clear();
                                      p.hsnController.clear();
                                      p.gstController.clear();
                                    }
                                    products.clear();
                                    products.add(Product()); // Keep one empty row
                                  });
                                  _updateTotal();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Clear', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
              ),
            ),

            ValueListenableBuilder<double>(
              valueListenable: totalNotifier,
              builder: (context, total, _) {
                return Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                        Text(total.toStringAsFixed(2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('Generate • Print • Share PDF', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: generatePDF,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  String companyName = '';
  String gstin = '';
  String address = '';
  String? logoBase64;
  final List<Map<String, String>> products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      companyName = prefs.getString('companyName') ?? 'Your Shop Name';
      gstin = prefs.getString('gstin') ?? '27AAAAA0000A1Z5';
      address = prefs.getString('address') ?? 'Your Shop Address';
      final json = prefs.getString('savedProducts');
      if (json != null) {
        savedProducts = List<Map<String, dynamic>>.from(jsonDecode(json));
        products.addAll(savedProducts.map((e) => Map<String, String>.from(e)));
      }
    });
  }

  void _addProduct() => setState(() => products.add({'name': '', 'hsn': '', 'rate': '', 'gst': ''}));
  void _removeProduct(int i) => setState(() => products.removeAt(i));

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await prefs.setString('companyName', companyName);
      await prefs.setString('gstin', gstin);
      await prefs.setString('address', address);

      companyNotifier.value = companyName;
      gstinNotifier.value = gstin;
      addressNotifier.value = address;

      savedProducts = products.map((p) => {
            'name': p['name'] ?? '',
            'hsn': p['hsn'] ?? '',
            'rate': p['rate'] ?? '',
            'gst': p['gst'] ?? '',
          }).toList();
      await prefs.setString('savedProducts', jsonEncode(savedProducts));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Company Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                border: OutlineInputBorder(),
              ),
              initialValue: companyName,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => companyName = v!.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'GSTIN *',
                border: OutlineInputBorder(),
              ),
              initialValue: gstin,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => gstin = v!.trim(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Address *',
                border: OutlineInputBorder(),
              ),
              initialValue: address,
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => address = v!.trim(),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...products.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: p['name'],
                        onChanged: (v) => p['name'] = v,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'HSN',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: p['hsn'],
                              onChanged: (v) => p['hsn'] = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Rate',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: p['rate'],
                              onChanged: (v) => p['rate'] = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'GST%',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: p['gst'],
                              onChanged: (v) => p['gst'] = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeProduct(i),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Save All Settings', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}