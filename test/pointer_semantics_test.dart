import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_differences_game/main.dart';

void main() {
  testWidgets(
    'image semantics never synthesizes a coordinate-free tap and pointers still find the same spot on both sides',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const MyApp());
        for (int i = 0; i < 12 && find.text('开始观察').evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('开始观察'), findsOneWidget);
        await tester.tap(find.text('开始观察'));
        await tester.pump();
        final a = find.bySemanticsLabel('A · 原场景，方向键移动光标，Enter确认');
        final b = find.bySemanticsLabel('B · 变化场景，方向键移动光标，Enter确认');
        expect(
          tester
              .getSemantics(a)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        final ra = tester.getRect(a), rb = tester.getRect(b);
        final point = Offset(
          ra.left + ra.width * .8765,
          ra.top + ra.height * .1405,
        );
        await tester.tapAt(point);
        await tester.pump();
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('1000'), findsOneWidget);
        await tester.tapAt(
          Offset(rb.left + rb.width * .8765, rb.top + rb.height * .1405),
        );
        await tester.pump();
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('1000'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      } finally {
        semantics.dispose();
      }
    },
  );
}
