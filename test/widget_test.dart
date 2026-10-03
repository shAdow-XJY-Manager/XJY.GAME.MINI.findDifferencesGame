import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_differences_game/main.dart';

void main() {
  testWidgets('difference game loads its audited scene before starting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    for (var i = 0; i < 100 && find.text('开始观察').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(find.text('双频找不同'), findsOneWidget);
    expect(find.text('开始观察'), findsOneWidget);
    await tester.tap(find.text('开始观察'));
    await tester.pump();
    expect(find.text('开始观察'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'real 320 and 390 width at 200 percent text keeps controls and both picture labels complete',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final errors = <Object>[];
      void collectErrors() {
        Object? error;
        while ((error = tester.takeException()) != null) {
          errors.add(error!);
        }
      }

      Future<void> frame([Duration duration = Duration.zero]) async {
        await tester.pump(duration);
        collectErrors();
      }

      Future<void> tapVisible(Finder target) async {
        expect(target, findsOneWidget);
        await tester.ensureVisible(target);
        await frame();
        expect(target.hitTestable(), findsOneWidget);
        expect(MediaQuery.textScalerOf(tester.element(target)).scale(14), 28);
        final labels = find.descendant(of: target, matching: find.byType(Text));
        for (var i = 0; i < labels.evaluate().length; i++) {
          _expectFullText(tester, labels.at(i), errors);
        }
        await tester.tap(target.hitTestable());
        await frame();
      }

      try {
        // Load the real metadata in the real async zone before the widget asks
        // for it; rootBundle otherwise retains a Future from the prior test.
        await tester.runAsync(() async {
          rootBundle.evict('assets/images/frequency-levels.json');
          final metadata = await rootBundle.loadString(
            'assets/images/frequency-levels.json',
          ).timeout(const Duration(seconds: 3));
          expect(metadata, isNotEmpty);
        });
        await tester.pumpWidget(_doubleTextApp());
        collectErrors();
        await frame();

        for (var i = 0; i < 100 && find.text('开始观察').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await frame();
        }
        final start = _buttonText('开始观察');
        final pause = _buttonText('暂停');
        expect(
          start,
          findsOneWidget,
          reason: 'Current scene text: ${tester.widgetList<Text>(find.byType(Text, skipOffstage: false)).map((text) => text.data ?? text.textSpan?.toPlainText()).join(' | ')}\n'
              'Framework exceptions: ${errors.join('\n')}',
        );
        expect(MediaQuery.sizeOf(tester.element(start)), const Size(320, 800));
        expect(MediaQuery.textScalerOf(tester.element(start)).scale(14), 28);
        expect(tester.widget<OutlinedButton>(pause).onPressed, isNull);
        await frame(const Duration(milliseconds: 100));
        expect(start, findsOneWidget);
        await tapVisible(start);
        expect(find.text('开始观察'), findsNothing);
        final hint = _buttonText('提示 2 / 2 · −200分');
        expect(tester.widget<OutlinedButton>(hint).onPressed, isNotNull);
        await tapVisible(hint);
        final usedHint = _buttonText('提示 1 / 2 · −200分');
        expect(usedHint, findsOneWidget);
        expect(find.byTooltip('放大'), findsOneWidget);
        expect(find.byTooltip('缩小'), findsOneWidget);
        await frame(const Duration(milliseconds: 16));
        await tapVisible(pause);
        expect(find.text('观察已暂停'), findsOneWidget);
        expect(tester.widget<OutlinedButton>(usedHint).onPressed, isNull);
        await tapVisible(_buttonText('继续观察'));
        expect(find.text('观察已暂停'), findsNothing);
        expect(tester.widget<OutlinedButton>(usedHint).onPressed, isNotNull);
        for (final width in [320.0, 390.0]) {
          tester.view.physicalSize = Size(width, 800);
          await frame();
          for (final label in ['A · 原场景', 'B · 变化场景']) {
            final text = find.text(label);
            final picture = find
                .ancestor(
                  of: text,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is SizedBox &&
                        widget.width != null &&
                        widget.height != null,
                  ),
                )
                .first;
            await tester.ensureVisible(picture);
            await frame();
            final viewportRect = tester.getRect(picture);
            final labelRect = tester.getRect(text);
            expect(viewportRect.left, greaterThanOrEqualTo(-1));
            expect(viewportRect.right, lessThanOrEqualTo(width + 1));
            expect(viewportRect.top, greaterThanOrEqualTo(-1));
            expect(viewportRect.bottom, lessThanOrEqualTo(801));
            expect(labelRect.left, greaterThanOrEqualTo(viewportRect.left - 1));
            expect(labelRect.right, lessThanOrEqualTo(viewportRect.right + 1));
            _expectFullText(tester, text, errors);
          }
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        collectErrors();
        await frame();
      }
      expect(
        errors,
        isEmpty,
        reason: errors.map((e) => e.toString()).join('\n\n'),
      );
    },
  );
}

Widget _doubleTextApp() => Builder(
  builder: (context) {
    final app = const MyApp().build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
      title: app.title,
      theme: app.theme,
      home: app.home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child!,
      ),
    );
  },
);

void _expectFullText(WidgetTester tester, Finder text, List<Object> errors) {
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
  expect(MediaQuery.textScalerOf(tester.element(text)).scale(14), 28);
  expect(paragraph.textScaler.scale(14), 28);
  if (paragraph.size.height + 1 < needed || paragraph.didExceedMaxLines) {
    errors.add(
      FlutterError(
        '${paragraph.text.toPlainText()} needs $needed px but has ${paragraph.size.height} px '
        'at ${MediaQuery.sizeOf(tester.element(text)).width} px viewport; '
        'didExceedMaxLines=${paragraph.didExceedMaxLines}',
      ),
    );
  }
}

Finder _buttonText(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);
