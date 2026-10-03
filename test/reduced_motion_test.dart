import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:find_differences_game/main.dart';
import 'package:flutter/services.dart';

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

void main() {
  testWidgets('real controls combine manual and system reduced motion without losing viewport or text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    final systemReduced = ValueNotifier<bool>(false);
    late InteractiveInkFeatureFactory normalSplash;
    final errors = <String>[];
    final bindingErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.toString());
      bindingErrorHandler?.call(details);
    };

    Widget host() => Builder(builder: (context) {
      final app = const MyApp().build(context) as MaterialApp;
      normalSplash = app.theme!.splashFactory;
      return MaterialApp(
        debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
        title: app.title,
        theme: app.theme,
        home: app.home,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: systemReduced,
          child: child,
          builder: (context, system, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: system,
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
        ),
      );
    });

    Future<void> frame([Duration duration = Duration.zero]) async {
      await tester.pump(duration);
      final exception = tester.takeException();
      if (exception != null) errors.add(exception.toString());
    }

    Future<void> tapVisible(Finder control) async {
      expect(control, findsOneWidget);
      await tester.ensureVisible(control);
      await frame();
      expect(control.hitTestable(), findsOneWidget);
      await tester.tap(control.hitTestable());
      await frame(const Duration(milliseconds: 16));
    }

    Future<void> checkControls(bool effective, String manualTooltip) async {
      expect(find.text('开始观察'), findsNothing, reason: 'preference changes must retain the playing game');
      final controls = [find.byTooltip(manualTooltip), _button('暂停'), ...[_button('提示 2 / 2 · −200分')]];
      for (final control in controls) {
        expect(control, findsOneWidget);
        await tester.ensureVisible(control);
        await frame();
        expect(control.hitTestable(), findsOneWidget);
        final context = tester.element(control);
        expect(MediaQuery.disableAnimationsOf(context), effective);
        expect(MediaQuery.sizeOf(context), const Size(320, 800));
        expect(MediaQuery.textScalerOf(context).scale(14), 28);
        expect(Theme.of(context).splashFactory,
          same(effective ? NoSplash.splashFactory : normalSplash));
        final labels = find.descendant(of: control, matching: find.byType(Text));
        for (var i = 0; i < labels.evaluate().length; i++) {
          final paragraph = tester.renderObject<RenderParagraph>(labels.at(i));
          expect(paragraph.textScaler.scale(14), 28);
        }
      }
    }

    try {

      // The real metadata Future must belong to this test's real async zone.
      await tester.runAsync(() async {
        rootBundle.evict('assets/images/frequency-levels.json');
        await rootBundle.loadString('assets/images/frequency-levels.json')
          .timeout(const Duration(seconds: 3));
      });

      await tester.pumpWidget(host());
      await frame();
      for (var i = 0; i < 100 && find.text('开始观察').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await frame();
      }
      expect(normalSplash, isNot(same(NoSplash.splashFactory)));
      await tapVisible(_button('开始观察'));
      await checkControls(false, '减少动态效果'); // manual off, system off.
      await tapVisible(find.byTooltip('减少动态效果'));
      await checkControls(true, '开启动态效果'); // manual on, system off.
      systemReduced.value = true;
      await frame();
      await checkControls(true, '开启动态效果'); // manual on, system on.
      await tapVisible(find.byTooltip('开启动态效果'));
      await checkControls(true, '减少动态效果'); // manual off, system on.
      systemReduced.value = false;
      await frame();
      await checkControls(false, '减少动态效果'); // Both off restores normal splash.
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await frame();
      } finally {
        FlutterError.onError = bindingErrorHandler;
        systemReduced.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    }
    expect(errors, isEmpty, reason: errors.join('\n\n'));
  });
}
