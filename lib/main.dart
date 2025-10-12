import 'package:flutter/material.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Later: Initialize Hive, audio, settings here

  runApp(const CaesarApp());
}
