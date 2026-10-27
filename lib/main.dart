import 'package:flutter/material.dart';

import 'demo/hiveflow_demo.dart';
import 'screens/dashboard_screen.dart';
import 'theme/hiveflow_palette.dart';

void main() {
  runApp(const HiveFlowApp());
}

class HiveFlowApp extends StatelessWidget {
  const HiveFlowApp({this.controller, super.key});

  final HiveFlowDemoController? controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: HiveFlowPalette.lime,
      brightness: Brightness.dark,
      primary: HiveFlowPalette.lime,
      secondary: HiveFlowPalette.mint,
      surface: HiveFlowPalette.surface,
    );
    const canvas = HiveFlowPalette.canvas;

    return MaterialApp(
      title: 'HiveFlow | Fleet command',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: canvas,
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: HiveFlowPalette.surface,
          foregroundColor: HiveFlowPalette.text,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: HiveFlowPalette.surfaceRaised,
          contentTextStyle: const TextStyle(color: HiveFlowPalette.text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: HiveFlowPalette.sidebar,
          indicatorColor: HiveFlowPalette.lime,
          surfaceTintColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? HiveFlowPalette.sidebar
                  : HiveFlowPalette.muted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? HiveFlowPalette.sidebar
                  : HiveFlowPalette.muted,
              fontSize: 10,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
      home: HiveFlowHome(controller: controller ?? HiveFlowDemoController()),
    );
  }
}
