import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_differences_game/main.dart';

void main() {
  testWidgets(
    '390px zoom keeps both image viewports and labels in place with shared scaling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(const MyApp());
        for (var i = 0; i < 100 && find.text('开始观察').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.tap(find.text('开始观察'));
        await tester.pump();
        final viewers = find.byType(InteractiveViewer);
        expect(viewers, findsNWidgets(2));
        final labels = [find.text('A · 原场景'), find.text('B · 变化场景')];
        final labelRects = [for (final label in labels) tester.getRect(label)];
        final viewRects = [
          tester.getRect(viewers.at(0)),
          tester.getRect(viewers.at(1)),
        ];
        await tester.tap(find.byTooltip('放大'));
        await tester.pump();
        await tester.tap(find.byTooltip('放大'));
        await tester.pump();
        final first = tester.widget<InteractiveViewer>(viewers.at(0));
        final second = tester.widget<InteractiveViewer>(viewers.at(1));
        expect(
          identical(
            first.transformationController,
            second.transformationController,
          ),
          isTrue,
        );
        expect(first.transformationController!.value.getMaxScaleOnAxis(), 2);
        for (var i = 0; i < 2; i++) {
          expect(tester.getRect(labels[i]), labelRects[i]);
          final rect = tester.getRect(viewers.at(i));
          expect(rect, viewRects[i]);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(390));
        }
        for (var i = 0; i < 2; i++) {
          await tester.ensureVisible(viewers.at(i));
          await tester.pump();
          final rect = tester.getRect(viewers.at(i));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(844));
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
