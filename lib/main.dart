import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

late SharedPreferences prefs;
Uint8List? logoBytes;
List<Map<String, dynamic>> savedProducts = []; // ← GLOBAL

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  final base64 = prefs.getString('logoBase64');
  if (base64 != null) {
    try {
      logoBytes = base64Decode(base64);
    } catch (e) {}
  }
  final productsJson = prefs.getString('savedProducts');
  if (productsJson != null) {
    savedProducts = List<Map<String, dynamic>>.from(jsonDecode(productsJson));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GST Bill Generator',
      theme: ThemeData(primarySwatch: Colors.indigo),
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
}

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});
  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _formKey = GlobalKey<FormState>();
  String companyName = 'Your Shop Name';
  String gstin = '27AAAAA0000A1Z5';
  String address = 'Your Shop Address';
  String customerName = '';
  final List<Product> products = [Product()];
  int invoiceNo = 1;

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
      invoiceNo = (prefs.getInt('invoiceNo') ?? 0) + 1;
    });
  }

  Future<void> _saveInvoice() async {
    await prefs.setInt('invoiceNo', invoiceNo);
  }

  void addProduct() => setState(() => products.add(Product()));
  void removeProduct(int index) => setState(() => products.removeAt(index));

  double get subtotal => products.fold(0, (s, p) => s + p.qty * p.rate);
  double get totalCGST => products.fold(0, (s, p) => s + (p.qty * p.rate * (p.gstPercent / 2) / 100));
  double get totalSGST => totalCGST;
  double get grandTotal => subtotal + totalCGST + totalSGST;

  String numberToWords(int number) {
    if (number == 0) return 'Zero';
    final List<String> ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final List<String> tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    String word = '';
    if (number >= 10000000) { word += '${numberToWords(number ~/ 10000000)} Crore '; number %= 10000000; }
    if (number >= 100000) { word += '${numberToWords(number ~/ 100000)} Lakh '; number %= 100000; }
    if (number >= 1000) { word += '${numberToWords(number ~/ 1000)} Thousand '; number %= 1000; }
    if (number >= 100) { word += '${ones[number ~/ 100]} Hundred '; number %= 100; }
    if (number > 0) {
      if (number < 20) word += ones[number];
      else { word += tens[number ~/ 10]; if (number % 10 > 0) word += ' ${ones[number % 10]}'; }
    }
    return word.trim();
  }

  String get totalInWords => '${numberToWords(grandTotal.round())} Rupees Only';

  Future<void> generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await _saveInvoice();

    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final ttf = pw.Font.courier();

    pw.Widget? logoWidget;
    if (logoBytes != null) {
      final image = pw.MemoryImage(logoBytes!);
      logoWidget = pw.SizedBox(width: 80, height: 80, child: pw.Image(image, fit: pw.BoxFit.contain));
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoWidget != null) logoWidget,
            if (logoWidget != null) pw.SizedBox(width: 20),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(companyName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, font: ttf)),
              pw.Text(address, style: pw.TextStyle(fontSize: 12, font: ttf)),
              pw.Text('GSTIN: $gstin', style: pw.TextStyle(fontSize: 14, font: ttf)),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Invoice No: $invoiceNo', style: pw.TextStyle(font: ttf)),
            pw.Text('Date: $date', style: pw.TextStyle(font: ttf)),
          ]),
          pw.Text('Bill to: $customerName', style: pw.TextStyle(font: ttf)),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.Table.fromTextArray(
          headers: ['#', 'Item', 'HSN/Details', 'Qty', 'Rate', 'Taxable', 'CGST', 'SGST', 'Total'],
          data: products.asMap().entries.map((e) {
            final i = e.key + 1;
            final p = e.value;
            final taxable = p.qty * p.rate;
            final cgst = taxable * (p.gstPercent / 2) / 100;
            final sgst = cgst;
            final total = taxable + cgst + sgst;
            return [
              i.toString(),
              p.name,
              p.details,
              p.qty.toString(),
              'Rs.${p.rate.toStringAsFixed(2)}',
              'Rs.${taxable.toStringAsFixed(2)}',
              'Rs.${cgst.toStringAsFixed(2)}',
              'Rs.${sgst.toStringAsFixed(2)}',
              'Rs.${total.toStringAsFixed(2)}',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf),
          cellStyle: pw.TextStyle(font: ttf),
        ),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(children: [
            pw.Text('Subtotal: Rs.${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf)),
            pw.Text('CGST: Rs.${totalCGST.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf)),
            pw.Text('SGST: Rs.${totalSGST.toStringAsFixed(2)}', style: pw.TextStyle(font: ttf)),
            pw.Text('Grand Total: Rs.${grandTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf)),
            pw.Text('In Words: $totalInWords', style: pw.TextStyle(font: ttf)),
          ]),
        ),
        pw.Spacer(),
        pw.Center(child: pw.Text('Thank You! Visit Again', style: pw.TextStyle(font: ttf))),
      ]),
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/GST_Bill_$invoiceNo.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'GST Bill #$invoiceNo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Bill Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _loadData();
              setState(() {});
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            if (logoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(logoBytes!, width: 60, height: 60, fit: BoxFit.cover),
              ),
            if (logoBytes != null) const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(gstin),
                Text(address, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ]),
          const Divider(),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Customer Name *'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: (v) => customerName = v!.trim(),
          ),
          const Divider(height: 30),
          ...products.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return savedProducts
                          .where((prod) => prod['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()))
                          .map((prod) => prod['name'].toString());
                    },
                    onSelected: (String selection) {
                      final selected = savedProducts.firstWhere((prod) => prod['name'] == selection);
                      p.name = selected['name'];
                      p.details = selected['hsn'];
                      p.rate = double.tryParse(selected['rate'].toString()) ?? 0;
                      p.gstPercent = double.tryParse(selected['gst'].toString()) ?? 18;
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = p.name;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Product Name *'),
                        onChanged: (v) => p.name = v,
                      );
                    },
                  ),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'HSN / Details'),
                    controller: TextEditingController(text: p.details)..selection = TextSelection.fromPosition(TextPosition(offset: p.details.length)),
                    onChanged: (v) => p.details = v,
                  ),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Qty'),
                        keyboardType: TextInputType.number,
                        initialValue: p.qty.toString(),
                        onChanged: (v) => p.qty = int.tryParse(v) ?? 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Rate'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: p.rate > 0 ? p.rate.toStringAsFixed(2) : ''),
                        onChanged: (v) => p.rate = double.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'GST%'),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: p.gstPercent > 0 ? p.gstPercent.toString() : ''),
                        onChanged: (v) => p.gstPercent = double.tryParse(v) ?? 18,
                      ),
                    ),
                  ]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: products.length > 1 ? () => removeProduct(i) : null,
                    ),
                  ),
                ]),
              ),
            );
          }),
          ElevatedButton(onPressed: addProduct, child: const Text('Add Product')),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Total: Rs.${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate • Print • Share PDF'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            onPressed: generatePDF,
          ),
        ]),
      ),
    );
  }
}

// ADMIN SETTINGS PAGE
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
      logoBase64 = prefs.getString('logoBase64');
      if (logoBase64 != null) {
        try {
          logoBytes = base64Decode(logoBase64!);
        } catch (e) {}
      }
      final json = prefs.getString('savedProducts');
      if (json != null) {
        savedProducts = List<Map<String, dynamic>>.from(jsonDecode(json));
        products.addAll(savedProducts.map((e) => Map<String, String>.from(e)));
      }
    });
  }

  void _addProduct() {
    setState(() {
      products.add({'name': '', 'hsn': '', 'rate': '', 'gst': ''});
    });
  }

  void _removeProduct(int index) {
    setState(() {
      products.removeAt(index);
    });
  }

  void _saveData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      prefs.setString('companyName', companyName);
      prefs.setString('gstin', gstin);
      prefs.setString('address', address);
      if (logoBase64 != null && logoBase64!.isNotEmpty) {
        try {
          logoBytes = base64Decode(logoBase64!);
          prefs.setString('logoBase64', logoBase64!);
        } catch (e) {}
      }
      // Save products
      savedProducts = products.map((p) => {
        'name': p['name'] ?? '',
        'hsn': p['hsn'] ?? '',
        'rate': p['rate'] ?? '',
        'gst': p['gst'] ?? '',
      }).toList();
      prefs.setString('savedProducts', jsonEncode(savedProducts));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All Saved!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Settings')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: logoBytes != null ? MemoryImage(logoBytes!) : null,
              child: logoBytes == null ? const Icon(Icons.business, size: 50) : null,
            ),
          ),
          const SizedBox(height: 10),
          const Text('Paste Base64 logo (optional)', textAlign: TextAlign.center),
          TextFormField(
            decoration: const InputDecoration(hintText: 'iVBORw0KGgoAAAANSUhEUgAA...'),
            maxLines: 3,
            initialValue: logoBase64,
            onSaved: (v) => logoBase64 = v?.trim(),
          ),
          const Divider(height: 30),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Company Name *'),
            initialValue: companyName,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: (v) => companyName = v!.trim(),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'GSTIN *'),
            initialValue: gstin,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: (v) => gstin = v!.trim(),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Address *'),
            initialValue: address,
            maxLines: 3,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: (v) => address = v!.trim(),
          ),
          const Divider(height: 30),
          const Text('Add Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...products.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Product Name *'),
                    initialValue: p['name'],
                    onChanged: (v) => p['name'] = v,
                  ),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'HSN'),
                        initialValue: p['hsn'],
                        onChanged: (v) => p['hsn'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Rate'),
                        keyboardType: TextInputType.number,
                        initialValue: p['rate'],
                        onChanged: (v) => p['rate'] = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'GST%'),
                        keyboardType: TextInputType.number,
                        initialValue: p['gst'],
                        onChanged: (v) => p['gst'] = v,
                      ),
                    ),
                  ]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeProduct(i),
                    ),
                  ),
                ]),
              ),
            );
          }),
          ElevatedButton(onPressed: _addProduct, child: const Text('Add Product')),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _saveData,
            child: const Text('Save All Settings'),
          ),
        ]),
      ),
    );
  }
}