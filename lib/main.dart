import 'package:flutter/material.dart';
import 'package:pansiyon_yonetim/app/pansiyon_yonetim_app.dart';
import 'package:pansiyon_yonetim/core/database/sqflite_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ensureSqfliteFfiInitialized();
  runApp(const PansiyonYonetimApp());
}
