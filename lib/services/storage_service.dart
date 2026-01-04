import 'dart:convert';
import '../globals.dart';

void loadGlobalData() {
  companyNotifier.value = prefs.getString('companyName') ?? 'Your Shop Name';
  gstinNotifier.value = prefs.getString('gstin') ?? '27AAAAA0000A1Z5';
  addressNotifier.value = prefs.getString('address') ?? 'Your Shop Address';

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

Future<void> saveCustomerPhone(String customerName, String customerPhone) async {
  if (customerName.isNotEmpty && customerPhone.isNotEmpty) {
    customerPhoneMap[customerName] = customerPhone;
    await prefs.setString('customerPhones', jsonEncode(customerPhoneMap));
  }
}

Future<void> saveSettings(String companyName, String gstin, String address, List<Map<String, dynamic>> products) async {
  await prefs.setString('companyName', companyName);
  await prefs.setString('gstin', gstin);
  await prefs.setString('address', address);

  companyNotifier.value = companyName;
  gstinNotifier.value = gstin;
  addressNotifier.value = address;

  savedProducts = products;
  await prefs.setString('savedProducts', jsonEncode(savedProducts));
}