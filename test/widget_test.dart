// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:highflow/demo/hiveflow_demo.dart';
import 'package:highflow/main.dart';

void main() {
  testWidgets('shows the HiveFlow overview and local preview status', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      HiveFlowApp(
        key: const ValueKey('desktop'),
        controller: HiveFlowDemoController(autoStart: false),
      ),
    );

    expect(find.text('HiveFlow'), findsOneWidget);
    expect(
      find.text('The brain behind a\nbetter-moving warehouse.'),
      findsOneWidget,
    );
    expect(find.text('LOCAL PREVIEW'), findsWidgets);
    expect(find.text('0 steps'), findsOneWidget);
    expect(find.text('Block Aisle 3'), findsOneWidget);
    expect(find.text('Live pick missions'), findsOneWidget);
    expect(find.text('Tote 108 · bolts'), findsOneWidget);
    expect(find.textContaining('PICKUP'), findsNWidgets(8));

    await tester.ensureVisible(find.text('Block Aisle 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block Aisle 3'));
    await tester.pumpAndSettle();

    expect(find.text('Aisle 3 marked blocked'), findsOneWidget);
    expect(find.text('Reopen Aisle 3'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('shows bottom navigation on a phone-sized screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      HiveFlowApp(
        key: const ValueKey('phone'),
        controller: HiveFlowDemoController(autoStart: false),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Demo'), findsOneWidget);
    expect(find.text('Fleet'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Ops'), findsOneWidget);

    await tester.tap(find.text('Demo'));
    await tester.pumpAndSettle();
    expect(find.text('Same warehouse. Two approaches.'), findsOneWidget);
    expect(find.text('BASELINE'), findsOneWidget);
    expect(find.text('HIVEFLOW'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('fits a compact 320-pixel phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      HiveFlowApp(
        key: const ValueKey('compact-phone'),
        controller: HiveFlowDemoController(autoStart: false),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
    expect(
      find.text('The brain behind a\nbetter-moving warehouse.'),
      findsOneWidget,
    );

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets(
    'shows scanner choices and phone connection help in Warehouse Ops',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        HiveFlowApp(
          key: const ValueKey('warehouse-ops'),
          controller: HiveFlowDemoController(autoStart: false),
        ),
      );

      await tester.tap(find.text('Ops'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Scanner options'), findsOneWidget);
      expect(find.text('QR label + simulated robot scans'), findsOneWidget);
      expect(
        find.text('QR label + live phone camera scanning'),
        findsOneWidget,
      );
      expect(find.text('Barcode scanner input'), findsOneWidget);
      expect(find.text('RFID reader integration'), findsOneWidget);
      expect(find.text('Phone setup'), findsOneWidget);

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
