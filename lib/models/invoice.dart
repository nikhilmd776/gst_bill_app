class Invoice {
  final int? id;
  final String invoiceNumber;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final double totalAmount;
  final double gstAmount;
  final String invoiceType; // 'estimate' or 'invoice'
  final DateTime createdDate;
  final String? pdfPath;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.totalAmount,
    required this.gstAmount,
    required this.invoiceType,
    required this.createdDate,
    this.pdfPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'total_amount': totalAmount,
      'gst_amount': gstAmount,
      'invoice_type': invoiceType,
      'created_date': createdDate.toIso8601String(),
      'pdf_path': pdfPath,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      invoiceNumber: map['invoice_number'],
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      customerAddress: map['customer_address'],
      totalAmount: map['total_amount'],
      gstAmount: map['gst_amount'],
      invoiceType: map['invoice_type'],
      createdDate: DateTime.parse(map['created_date']),
      pdfPath: map['pdf_path'],
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? totalAmount,
    double? gstAmount,
    String? invoiceType,
    DateTime? createdDate,
    String? pdfPath,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      totalAmount: totalAmount ?? this.totalAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      invoiceType: invoiceType ?? this.invoiceType,
      createdDate: createdDate ?? this.createdDate,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }
}