import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator/main.dart';

void main() {
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'phone landscape': Size(844, 390),
    'tablet': Size(820, 1180),
    'tablet landscape': Size(1180, 820),
    'desktop': Size(1920, 1080),
    'tiny window': Size(240, 300),
  };

  for (final entry in sizes.entries) {
    testWidgets('lays out without overflow on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CalculatorApp());
      expect(tester.takeException(), isNull);
      expect(find.text('='), findsOneWidget);
    });
  }

  testWidgets('basic calculation works', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    for (final k in ['1', '2', '+', '3', '=']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    expect(find.text('15'), findsWidgets);
  });
}
