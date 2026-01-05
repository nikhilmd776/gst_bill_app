import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../utils/number_to_words.dart';
import '../globals.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import 'database_service.dart';

Future<void> generateAndSharePDF(
  BuildContext context,
  List<Product> products,
  String customerName,
  String customerPhone,
  String customerAddress,
  String invoiceType,
) async {
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
    p.gstPercent = double.tryParse(p.gstController.text) ?? 0;
    p.details = p.hsnController.text;
  }

  double subtotal = 0.0;
  double totalGST = 0.0;
  for (final p in products) {
    subtotal += p.taxable;
    totalGST += p.gst;
  }
  double cgst = totalGST / 2;
  double sgst = totalGST / 2;

  if (customerName.isNotEmpty && customerPhone.isNotEmpty) {
    customerPhoneMap[customerName] = customerPhone;
    await prefs.setString('customerPhones', jsonEncode(customerPhoneMap));
  }

  final pdf = pw.Document();
  final now = DateTime.now();
  final date = DateFormat('dd MMM yyyy').format(now);
  final time = DateFormat('hh:mm a').format(now); // 08:21 PM
  final dateTime = '$date, $time';
  final today = DateFormat('yyyyMMdd').format(DateTime.now());
  final countKey = '$today-count';
  int dailyCount = prefs.getInt(countKey) ?? 0;
  dailyCount++;
  await prefs.setInt(countKey, dailyCount);
  final invoiceId = '$today-${dailyCount.toString().padLeft(3, '0')}';
  final font = await PdfGoogleFonts.robotoRegular();
  final bold = await PdfGoogleFonts.robotoBold();

  // Save invoice to database
  try {
    final invoice = Invoice(
      invoiceNumber: invoiceId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      totalAmount: totalNotifier.value,
      gstAmount: totalGST,
      invoiceType: invoiceType,
      createdDate: now,
    );

    final invoiceItems = products.map((product) => InvoiceItem(
      invoiceId: 0, // Will be set by database
      productName: product.name,
      hsnCode: product.details,
      quantity: product.qty,
      rate: product.rate,
      gstPercent: product.gstPercent,
    )).toList();

    await InvoiceDatabase.saveCompleteInvoice(invoice, invoiceItems);
  } catch (e) {
    // Log error but don't stop PDF generation
    debugPrint('Error saving invoice to database: $e');
  }

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
                    pw.Text('Invoice: #$invoiceId', style: pw.TextStyle(font: font)),
                    pw.Text('Date: $dateTime', style: pw.TextStyle(font: font)),
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
                // Bill To + Name
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To: ', style: pw.TextStyle(font: bold)),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(customerName, style: pw.TextStyle(font: font)),
                          if (pdfCustomerAddress.isNotEmpty)
                            pw.Text(pdfCustomerAddress, style: pw.TextStyle(font: font, fontSize: 10)),
                          if (customerPhone.isNotEmpty)
                            pw.Text('Phone: $customerPhone', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
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
                      pw.Text(subtotal.toStringAsFixed(2), style: pw.TextStyle(font: font)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CGST:', style: pw.TextStyle(font: font)),
                      pw.Text(cgst.toStringAsFixed(2), style: pw.TextStyle(font: font)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SGST:', style: pw.TextStyle(font: font)),
                      pw.Text(sgst.toStringAsFixed(2), style: pw.TextStyle(font: font)),
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
  final file = File('${dir.path}/Invoice_$invoiceId.pdf');
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([XFile(file.path)], text: 'Invoice #$invoiceId');
}