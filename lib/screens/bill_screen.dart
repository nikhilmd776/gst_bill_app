import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/pdf_service.dart';
import '../globals.dart';
import 'settings_screen.dart';

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
      p.dispose();
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
    p.dispose();
    setState(() => products.removeAt(index));
    _updateTotal();
  }

  Future<void> generatePDF() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await generateAndSharePDF(
      context,
      products,
      customerName,
      customerPhone,
      customerAddress,
      invoiceType,
    );
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
                          color: Colors.black.withValues(alpha: 0.25),
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
                      // ignore: deprecated_member_use
                      child: RadioListTile<String>(
                        title: const Text('Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
                        value: 'estimate',
                        groupValue: invoiceType,
                        onChanged: (val) => setState(() => invoiceType = val!),
                      ),
                    ),
                    Expanded(
                      // ignore: deprecated_member_use
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
                            p.gstPercent = double.tryParse(selected['gst'].toString()) ?? 0.0;

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
                                p.gstPercent = double.tryParse(v) ?? 0.0;
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
                                      p.gstPercent = 0.0;
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