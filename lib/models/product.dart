import 'package:flutter/material.dart';

class Product {
  String name = '';
  String details = '';
  int qty = 1;
  double rate = 0.0;
  double gstPercent = 0.0;

  final rateController = TextEditingController();
  final hsnController = TextEditingController();
  final gstController = TextEditingController();

  double get total => qty * rate * (1 + gstPercent / 100);
  double get taxable => qty * rate;
  double get gst => qty * rate * (gstPercent / 100);

  void dispose() {
    rateController.dispose();
    hsnController.dispose();
    gstController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'hsn': details,
      'rate': rate.toString(),
      'gst': gstPercent.toString(),
    };
  }

  static Product fromJson(Map<String, dynamic> json) {
    final product = Product();
    product.name = json['name'] ?? '';
    product.details = json['hsn'] ?? '';
    product.rate = double.tryParse(json['rate'].toString()) ?? 0.0;
    product.gstPercent = double.tryParse(json['gst'].toString()) ?? 0.0;
    return product;
  }
}