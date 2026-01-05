class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final String productName;
  final String? hsnCode;
  final int quantity;
  final double rate;
  final double gstPercent;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productName,
    this.hsnCode,
    required this.quantity,
    required this.rate,
    required this.gstPercent,
  });

  double get total => quantity * rate * (1 + gstPercent / 100);
  double get taxable => quantity * rate;
  double get gst => quantity * rate * (gstPercent / 100);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_name': productName,
      'hsn_code': hsnCode,
      'quantity': quantity,
      'rate': rate,
      'gst_percent': gstPercent,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoice_id'],
      productName: map['product_name'],
      hsnCode: map['hsn_code'],
      quantity: map['quantity'],
      rate: map['rate'],
      gstPercent: map['gst_percent'],
    );
  }

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    String? productName,
    String? hsnCode,
    int? quantity,
    double? rate,
    double? gstPercent,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productName: productName ?? this.productName,
      hsnCode: hsnCode ?? this.hsnCode,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      gstPercent: gstPercent ?? this.gstPercent,
    );
  }
}