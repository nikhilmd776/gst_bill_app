import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import 'database_service.dart';

class BackupService {
  static const String _backupFileName = 'gst_billing_backup.json';

  /// Export all invoice data to a JSON file and share it
  static Future<void> exportData(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exporting data...'),
            ],
          ),
        ),
      );

      // Get all invoices with their items
      final invoices = await InvoiceDatabase.getAllInvoices();
      final backupData = <Map<String, dynamic>>[];

      for (final invoice in invoices) {
        final result = await InvoiceDatabase.getCompleteInvoice(invoice.id!);
        if (result != null) {
          backupData.add({
            'invoice': invoice.toMap(),
            'items': (result['items'] as List).map((item) => item.toMap()).toList(),
          });
        }
      }

      // Create backup JSON
      final backupJson = jsonEncode({
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'totalInvoices': backupData.length,
        'data': backupData,
      });

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final backupFile = File('${tempDir.path}/$_backupFileName');
      await backupFile.writeAsString(backupJson);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Share the file
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'GST Billing App Data Backup - ${DateTime.now().toString().split(' ')[0]}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully! ${backupData.length} invoices backed up.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Import invoice data from a JSON backup file
  static Future<void> importData(BuildContext context) async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = File(result.files.first.path!);
      final backupJson = await file.readAsString();
      final backupData = jsonDecode(backupJson);

      // Validate backup format
      if (!backupData.containsKey('data') || backupData['data'] is! List) {
        throw Exception('Invalid backup file format');
      }

      final data = backupData['data'] as List;
      final totalInvoices = data.length;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Data'),
          content: Text(
            'This will import $totalInvoices invoices. Existing data will not be affected. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Importing data...'),
            ],
          ),
        ),
      );

      int importedCount = 0;
      int skippedCount = 0;

      // Import each invoice
      for (final entry in data) {
        try {
          final invoiceMap = entry['invoice'];
          final itemsList = entry['items'] as List;

          // Check if invoice already exists
          final existingInvoices = await InvoiceDatabase.searchInvoicesByCustomer(
            invoiceMap['customer_name'],
          );

          final invoiceNumberExists = existingInvoices.any(
            (inv) => inv.invoiceNumber == invoiceMap['invoice_number'],
          );

          if (invoiceNumberExists) {
            skippedCount++;
            continue;
          }

          // Create invoice object
          final invoice = Invoice.fromMap(invoiceMap);

          // Create invoice items
          final items = itemsList.map((itemMap) => InvoiceItem.fromMap(itemMap)).toList();

          // Save to database
          await InvoiceDatabase.saveCompleteInvoice(invoice, items);
          importedCount++;
        } catch (e) {
          debugPrint('Error importing invoice: $e');
          skippedCount++;
        }
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show result
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import completed! $importedCount imported, $skippedCount skipped.'),
            backgroundColor: importedCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Clear all data (with confirmation)
  static Future<void> clearAllData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all invoices and cannot be undone. '
          'Make sure you have a backup before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await InvoiceDatabase.clearAllData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Get backup statistics
  static Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final totalInvoices = await InvoiceDatabase.getInvoiceCount();
      final totalSales = await InvoiceDatabase.getTotalSales();

      return {
        'totalInvoices': totalInvoices,
        'totalSales': totalSales,
        'lastBackupDate': null, // Could be stored in preferences
      };
    } catch (e) {
      return {
        'totalInvoices': 0,
        'totalSales': 0.0,
        'lastBackupDate': null,
      };
    }
  }
}