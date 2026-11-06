import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinteros_launcher/src/settings/launcher_settings.dart';
import 'package:hinteros_launcher/src/theme/hinter_theme.dart';
import 'package:hinteros_launcher/src/ui/common.dart';
import 'package:hinteros_launcher/src/ui/visible_box.dart';

const _box = ValueKey('box');

/// A 300 px viewport over a 100 px gap and a 500 px bordered box.
Future<ScrollController> _pump(
  WidgetTester t, {
  double fadeBottom = 0,
  Border? border = const Border.fromBorderSide(BorderSide(width: 2)),
}) async {
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  Widget view = SingleChildScrollView(
    controller: scroll,
    child: Column(
      children: [
        const SizedBox(height: 100),
        VisibleDecoratedBox(
          key: _box,
          decoration: BoxDecoration(
            color: const Color(0xFF223344),
            border: border,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const SizedBox(height: 500, width: 400),
        ),
        const SizedBox(height: 400),
      ],
    ),
  );
  if (fadeBottom > 0) view = EdgeFade(top: 0, bottom: fadeBottom, child: view);
  await t.pumpWidget(
    HinterTheme(
      tokens: HinterTokens.fromSettings(const LauncherSettings()),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, height: 300, child: view),
        ),
      ),
    ),
  );
  return scroll;
}

RenderVisibleBox _render(WidgetTester t) =>
    t.renderObject<RenderVisibleBox>(find.byKey(_box));

void main() {
  testWidgets('a box cut by the viewport is drawn closed, shorter', (t) async {
    final scroll = await _pump(t);
    // 200 px show below the gap.
    expect(_render(t).visibleRect, const Rect.fromLTRB(0, 0, 400, 200));
    // Scrolled: the top is cut too, and the shown part follows.
    scroll.jumpTo(250);
    await t.pump();
    expect(_render(t).visibleRect, const Rect.fromLTRB(0, 150, 400, 450));
    // Scrolled past it: nothing shows.
    scroll.jumpTo(650);
    await t.pump();
    expect(_render(t).visibleRect.isEmpty, isTrue);
  });

  testWidgets('under a fade the box ends where the fade starts', (t) async {
    await _pump(t, fadeBottom: 40);
    expect(_render(t).visibleRect, const Rect.fromLTRB(0, 0, 400, 160));
  });

  testWidgets('without a border it is a plain DecoratedBox', (t) async {
    await _pump(t, border: null);
    expect(t.renderObject(find.byKey(_box)), isA<RenderDecoratedBox>());
  });
}
