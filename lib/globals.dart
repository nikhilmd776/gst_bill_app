import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SharedPreferences prefs;
List<Map<String, dynamic>> savedProducts = [];
Map<String, String> customerPhoneMap = {};

// GLOBAL NOTIFIERS
final companyNotifier = ValueNotifier<String>('Your Shop Name');
final gstinNotifier = ValueNotifier<String>('27AAAAA0000A1Z5');
final addressNotifier = ValueNotifier<String>('Your Shop Address');
final logoNotifier = ValueNotifier<Uint8List?>(null);

// Live total
final ValueNotifier<double> totalNotifier = ValueNotifier(0.0);