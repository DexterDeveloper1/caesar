import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class CaesarApp extends StatelessWidget {
  const CaesarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Caesar',
      theme: CaesarTheme.lightTheme,
      darkTheme: CaesarTheme.darkTheme,
      routerConfig: caesarRouter,
    );
  }
}
